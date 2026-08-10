<?php

namespace App\Services;

use App\Contracts\WhatsAppGateway;
use App\Models\Tenant;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Implementasi WhatsAppGateway via n8n webhook-test (proxy ke Evolution API).
 *
 * Backend Laravel jadi thin proxy — semua request via n8n, bukan Evolution direct.
 * Format & behavior persis dengan dokumentasi .docs/WA-GATEWAY-API.md.
 *
 * Kenapa n8n & bukan Evolution direct:
 * - n8n workflow fleksibel: bisa tambah branching/conditional/integrasi pihak
 *   ketiga tanpa edit Laravel (ex: log ke spreadsheet, retry policy custom).
 * - Credential Basic n8n cuma di server (tidak pernah bocor ke browser).
 * - Cloudflare WAF enpii block `GuzzleHttp/7` — kita pakai User-Agent Chrome.
 *
 * Auth: Basic, key `WA_GATEWAY_API_KEY` berformat "user:pass" di-encode base64.
 * Endpoints (lihat .docs/WA-GATEWAY-API.md "Daftar Endpoint"):
 *   POST   /create-instance     body { instance, phone }
 *   GET    /instance-state      ?instance=
 *   DELETE /delete-instance     ?instance=
 *   POST   /send-message        body { instance, number, text, delay }
 *   POST   /send-messages       body { instance, messages:[{number,text},...] }  -- belum dipakai
 *   GET    /history-message     ?instance=                                      -- belum dipakai
 *
 * Skipped: webhook inbound, send-media (lihat sendMedia() di bawah),
 * rate-limit per-instance, bulk-send optimisation.
 */
class N8nWaGateway implements WhatsAppGateway
{
    /**
     * Default template WA per status order. Dipakai kalau tenant belum
     * override di `wa_settings.templates[status]`. Token `{var}` di-substitusi
     * via `renderTemplate()` saat notif fired — `strtr` abaikan token yang
     * gak ada di $vars (unknown token left literal di output).
     *
     * Mirrors previous `EvolutionService::DEFAULT_TEMPLATES` supaya tenant
     * yang belum customize tidak melihat perubahan copy.
     */
    public const DEFAULT_TEMPLATES = [
        'masuk' => "Halo, laundry Anda di *{tenant_name}* (tiket *{ticket_number}*) sekarang berstatus: *Diterima*.",
        'dicuci' => "Halo, laundry Anda di *{tenant_name}* (tiket *{ticket_number}*) sekarang berstatus: *Sedang Dicuci*.",
        'selesai' => "Halo, laundry Anda di *{tenant_name}* (tiket *{ticket_number}*) sekarang berstatus: *Selesai*.",
        'diambil' => "Halo, laundry Anda di *{tenant_name}* (tiket *{ticket_number}*) sekarang berstatus: *Sudah Diambil*.",
        'dibatalkan' => "Halo, laundry Anda di *{tenant_name}* (tiket *{ticket_number}*) dibatalkan.",
    ];

    public function __construct(
        private string $baseUrl = '',
        private string $apiKey = '',
        private int $timeout = 15,
        private string $userAgent = '',
    ) {
        $this->baseUrl   = $this->baseUrl   !== '' ? $this->baseUrl   : (string) config('services.wa_gateway.base_url', '');
        $this->apiKey    = $this->apiKey    !== '' ? $this->apiKey    : (string) config('services.wa_gateway.api_key', '');
        $this->timeout   = $this->timeout   >  0  ? $this->timeout   : (int) config('services.wa_gateway.timeout', 15);
        $this->userAgent = $this->userAgent !== '' ? $this->userAgent : (string) config(
            'services.wa_gateway.user_agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                . '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        );
    }

    /**
     * Apakah env-level (base_url + api_key) sudah terisi.
     * Pemeriksaan instance-level ada di caller (Job) → cek wa_settings.instance.
     */
    public function isConfigured(): bool
    {
        return $this->baseUrl !== '' && $this->apiKey !== '';
    }

    /**
     * Pending HTTP client yang dipakai semua method. Header Basic + User-Agent
     * Chrome sudah diset di sini — caller tidak perlu ulangi.
     */
    private function http(): PendingRequest
    {
        return Http::withHeaders([
            'Authorization' => 'Basic ' . base64_encode($this->apiKey),
            'Content-Type'  => 'application/json',
            'Accept'        => 'application/json',
            'User-Agent'    => $this->userAgent,
        ])
            ->timeout($this->timeout)
            ->acceptJson()
            ->asJson();
    }

    /**
     * POST /create-instance
     *
     * Body n8n: { instance: <name>, phone: <owner_number> }
     * Response n8n: { success, instance: { name, status: connecting|open, qr?, pairingCode? } }
     *
     * Field `phone` (= nomor HP owner) dikirim supaya workflow n8n bisa
     * otomatis request pairing code ke Evolution setelah instance hidup.
     */
    public function createInstance(string $name, string $number): array
    {
        $this->assertConfigured();

        $response = $this->http()->post("{$this->baseUrl}/create-instance", [
            'instance' => $name,
            'phone'    => $number,
        ]);

        $this->assertSuccess($response, "create instance '{$name}'");

        return $this->extractInstance($response, $name);
    }

    /**
     * GET /instance-state?instance=
     *
     * Response: { success, instance: { name, status: connecting|open|close, qr? } }
     * `qr` hanya muncul saat status != open.
     */
    public function connectionState(string $instance): array
    {
        $this->assertConfigured();

        $response = $this->http()->get("{$this->baseUrl}/instance-state", [
            'instance' => $instance,
        ]);

        $this->assertSuccess($response, "check instance '{$instance}'");

        return $this->extractInstance($response, $instance);
    }

    /**
     * DELETE /delete-instance?instance=
     *
     * Idempotent — kalau 404 (instance sudah tidak ada), tetap return
     * `success=true` karena target state sudah tercapai.
     */
    public function deleteInstance(string $instance): array
    {
        $this->assertConfigured();

        $response = $this->http()->delete("{$this->baseUrl}/delete-instance", [
            'instance' => $instance,
        ]);

        if ($response->status() === 404) {
            return ['success' => true, 'already_absent' => true];
        }

        $this->assertSuccess($response, "delete instance '{$instance}'");

        return ['success' => true];
    }

    /**
     * Minta pairing code baru untuk instance yang sudah ada. n8n workflow
     * saat ini HANYA return pairing code 8-char dari endpoint create-instance
     * (lihat .docs/WA-GATEWAY-API.md §1) — endpoint instance-state tidak
     * return pairing code. Jadi cara dapat pairing code baru untuk instance
     * existing:
     *
     *   1. delete-instance   — drop instance lama dari n8n
     *   2. create-instance   — bikin ulang dengan nama + nomor sama
     *
     * Backend panggil 2 round-trip ini atomik supaya mobile dapat
     * `pairingCode` baru tanpa harus lewat flow Reset Koneksi manual
     * (yang confirm dialog + clear state). Owner HP tidak terganggu —
     * instance sebelumnya sudah stale di n8n sehingga delete idempotent
     * tidak mengganggu sesi WA aktif di HP.
     *
     * Lihat juga: docs §1 + §3 (create-instance + delete-instance).
     */
    public function regeneratePairing(string $instance, string $number): array
    {
        $this->assertConfigured();

        // Step 1: drop instance lama. Idempotent — 404 dianggap sukses.
        $this->deleteInstance($instance);

        // Step 2: create ulang dengan nama + nomor sama supaya
        // `wa_settings.instance` di backend tetap identik.
        return $this->createInstance($instance, $number);
    }

    /**
     * POST /send-message
     *
     * Body: { instance, number, text, delay }
     * `delay` random 1500-3500ms default — anti-spam detection WA.
     * Caller (controller) bisa inspect return `delay` untuk audit.
     */
    public function sendText(
        string $instance,
        string $phone,
        string $message,
        ?int $delayMs = null,
    ): array {
        $this->assertConfigured();

        $number = $this->normalizePhone($phone);
        $delay  = $delayMs ?? random_int(1500, 3500);

        $response = $this->http()->post("{$this->baseUrl}/send-message", [
            'instance' => $instance,
            'number'   => $number,
            'text'     => $message,
            'delay'    => $delay,
        ]);

        $this->assertSuccess($response, "send text to '{$number}' via '{$instance}'");

        return ['success' => true, 'delay' => $delay];
    }

    /**
     * sendMedia: BELUM di-support n8n workflow (per 2026-08-06).
     *
     * .docs/WA-GATEWAY-API.md hanya dokumentasi 6 endpoint di atas — tidak
     * ada `send-media`. Caller (`SendWaNotificationJob`) catch
     * RuntimeException & fallback ke `sendText` (text-only), jadi cukup
     * throw RuntimeException dengan pesan jelas.
     *
     * Track kerja: tambah method ini saat n8n expose endpoint-nya.
     */
    public function sendMedia(
        string $instance,
        string $phone,
        string $mediaPath,
        string $mime,
        string $fileName,
        ?string $caption = null,
    ): array {
        $this->assertConfigured();

        // Kalau nanti n8n expose /send-media, ganti implementasi di sini.
        // Untuk sekarang, fitur PDF nota tetap jalan: caller tangkap
        // exception → fallback sendText + log warning.
        throw new RuntimeException(
            'N8n WA gateway belum mendukung kirim lampiran (PDF/image). '
            . 'Notifikasi dikirim text-only. Lihat .docs/WA-GATEWAY-API.md.'
        );
    }

    /**
     * Normalisasi nomor HP → digits-only dengan country code 62 (ID default).
     * Ex: "+62 812-3456-7890" → "6281234567890"
     *     "081234567890"      → "6281234567890"
     *     "81234567890"       → "6281234567890"
     *
     * Lempar exception kalau hasil kosong atau terlalu pendek.
     */
    public function normalizePhone(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';

        // '+62...' / '62...' (already international)
        if (str_starts_with($digits, '62') && strlen($digits) >= 10) {
            return $digits;
        }
        // Lokal '0...' → tambah '62'
        if (str_starts_with($digits, '0') && strlen($digits) >= 9) {
            return '62' . substr($digits, 1);
        }
        // Tanpa prefix apa-apa, asumsikan lokal ID
        if (strlen($digits) >= 9) {
            return '62' . $digits;
        }

        throw new RuntimeException("Nomor WA tidak valid: '{$phone}'");
    }

    /**
     * Format tampilan Indonesia: "6281234567890" → "0812-3456-7890".
     */
    public static function formatPhoneId(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';
        if (str_starts_with($digits, '62')) {
            $digits = '0' . substr($digits, 2);
        }

        return trim(chunk_split($digits, 4, '-'), '-');
    }

    /**
     * Generate nama instance n8n otomatis untuk tenant ini.
     *
     * Format: `app-{tenant_slug}-{tenant_id}`
     *
     * - Prefix `app-` di-hardcode sesuai .docs/WA-GATEWAY-API.md (n8n workflow
     *   filter instance berdasarkan prefix ini).
     * - `slug` dari tenant (lowercase, dash-separated, via Str::slug()). Kalau
     *   tenant belum punya slug, fallback ke slugifikasi `$tenant->name`.
     * - Suffix `tenant_id` (numeric) supaya unik antar tenant.
     *
     * Contoh: tenant id=42, nama "Bumdesma Satu Desa Mandiri"
     *         → `app-bumdesma-satu-desa-mandiri-42`
     *
     * Karakter valid n8n: `[A-Za-z0-9_-]+` (sudah dipenuhi Str::slug()).
     *
     * Dipakai saat tenant pertama kali setup WA gateway — backend auto-generate
     * kalau `wa_settings.instance` masih kosong. Mobile tidak perlu input nama.
     */
    public static function generateInstanceName(string $phone, int $tenantId): string
    {
        $tenant = Tenant::query()->find($tenantId);
        $base = $tenant && !empty($tenant->slug)
            ? $tenant->slug
            : \Illuminate\Support\Str::slug((string) ($tenant->name ?? 'tenant'));

        return "app-{$base}-{$tenantId}";
    }

    /**
     * Substitute `{key}` token di $tpl dengan value dari $vars.
     * Pure `strtr` — unknown token left literal (sesuai requirement).
     *
     * Key di $vars HARUS sudah berformat `{name}` (dengan brace) — lihat
     * `renderForTenant()` untuk konvensi pemanggil.
     */
    public static function renderTemplate(string $tpl, array $vars): string
    {
        return strtr($tpl, $vars);
    }

    /**
     * Pilih template tenant override kalau ada & non-empty, else fallback ke
     * `DEFAULT_TEMPLATES[$status]`. Kalau $status juga gak ada di default
     * (edge case invalid status), return template kosong — caller udah
     * filter via `notify_on` jadi ini defensive.
     *
     * `$vars` keyed by `{token}` (e.g. `'{tenant_name}'` => 'Laundry A').
     */
    public static function renderForTenant(Tenant $tenant, string $status, array $vars): string
    {
        $templates = $tenant->waTemplates();
        $custom = $templates[$status] ?? null;

        $tpl = is_string($custom) && trim($custom) !== ''
            ? $custom
            : (self::DEFAULT_TEMPLATES[$status] ?? '');

        return self::renderTemplate($tpl, $vars);
    }

    // ============================================================
    // Internal helpers
    // ============================================================

    /**
     * Normalisasi response n8n. Shape docs:
     *   { success: true, instance: { name, status, qr?, pairingCode? } }
     *
     * Beberapa response pakai `data.instance` (older n8n format) — handle
     * dua-duanya dengan null-coalesce chain.
     */
    private function extractInstance(Response $response, string $fallbackName): array
    {
        $body = $response->json() ?? [];
        $instance = $body['instance']
            ?? $body['data']['instance']
            ?? [];

        // Normalisasi minimum shape — response sebenarnya bisa lebih kaya
        // (evolution raw fields, dsb) tapi caller cuma butuh subset ini.
        return [
            'success'      => (bool) ($body['success'] ?? $response->successful()),
            'instance'     => [
                'name'        => (string) ($instance['name'] ?? $fallbackName),
                'status'      => (string) ($instance['status'] ?? 'unknown'),
                'qr'          => $instance['qr'] ?? null,
                'pairingCode' => $instance['pairingCode']
                    ?? $instance['pairing_code']
                    ?? $instance['code']
                    ?? null,
                // State koneksi — Evolution return `state` (`connecting|open|close`)
                // sedangkan create-instance docs return `status`. Alias keduanya
                // supaya caller tidak perlu tau asal.
                'state'       => (string) (
                    $instance['state']
                    ?? $instance['status']
                    ?? ''
                ),
            ],
        ];
    }

    /**
     * Guard: gagal awal kalau env WA gateway belum di-set.
     */
    private function assertConfigured(): void
    {
        if (!$this->isConfigured()) {
            try {
                Log::error('WA Gateway env kosong', [
                    'base_url_set' => $this->baseUrl !== '',
                    'api_key_set'  => $this->apiKey !== '',
                ]);
            } catch (\Throwable $logErr) {
                // storage/logs/ permission denied — swallow, error_log
                // Linux fallback (lihat assertSuccess()).
                error_log('[wa-gateway] env not configured (log unavailable: '
                    . $logErr->getMessage() . ')');
            }
            throw new RuntimeException(
                'WA Gateway belum dikonfigurasi '
                . '(WA_GATEWAY_BASE / WA_GATEWAY_API_KEY kosong di .env).'
            );
        }
    }

    /**
     * Throw kalau response bukan 2xx. Pesan error membawa HTTP status + body
     * ringkas (max 500 char supaya tidak menuhin log).
     *
     * Kode error paling umum (dari pengalaman issue tracker n8n webhook-test):
     * - 401/403 "Authorization data is wrong!" → Basic credential salah
     * - 404 "webhook not registered" → path n8n tidak ada di workflow
     * - 500 "No Respond to Webhook node found" → workflow n8n belum ada Respond node
     */
    private function assertSuccess(Response $response, string $context): void
    {
        if ($response->successful()) {
            return;
        }

        $body = $response->body();
        $bodyForLog = strlen($body) > 2000 ? substr($body, 0, 2000) . '... (truncated)' : $body;

        // Log setiap error ke laravel.log dengan full context — penting
        // untuk debug n8n workflow (workflow belum ada, credential salah,
        // path tidak registered, dsb). Caller (controller) tetap throw
        // RuntimeException untuk stop alur + return error JSON ke mobile.
        //
        // transferStats adalah public property di Illuminate\Http\Client\Response.
        // Guzzle TransferStats API: getEffectiveUri(), getRequest()->getMethod().
        // Wrap dalam try/catch supaya method availability issue tidak mask error asli.
        try {
            $stats = $response->transferStats;
            $method = $stats?->getRequest()?->getMethod();
            $url    = $stats?->getEffectiveUri()?->__toString();
        } catch (\Throwable) {
            $method = null;
            $url = null;
        }
        try {
            Log::error('WA Gateway request gagal', [
                'context'    => $context,
                'method'     => $method,
                'url'        => $url,
                'status'     => $response->status(),
                'body'       => $bodyForLog,
                'headers_in' => $response->headers(),
            ]);
        } catch (\Throwable $logErr) {
            // storage/logs/ mungkin permission denied (root-owned file di
            // image, belum di-chown). LoggingException propagate sebagai
            // 500 ke caller dengan pesan panjang, padahal error asli
            // adalah 502 dari n8n / 401 credential salah. Jangan biarkan
            // logging crash alur — swallow + fallback error_log supaya
            // diagnosa upstream tidak hilang.
            error_log(sprintf(
                '[wa-gateway] log path unavailable: %s | gateway %s = %d',
                $logErr->getMessage(),
                $context,
                $response->status(),
            ));
        }

        $bodyForMsg = strlen($body) > 500 ? substr($body, 0, 500) . '... (truncated)' : $body;

        throw new RuntimeException(sprintf(
            'WA Gateway %s gagal [%d]: %s',
            $context,
            $response->status(),
            $bodyForMsg ?: '(empty body)'
        ));
    }
}
