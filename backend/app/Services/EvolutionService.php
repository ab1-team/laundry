<?php

namespace App\Services;

use App\Models\Tenant;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Wrapper Evolution API (https://doc.evolution-api.com/v2/api-reference/message/send-text).
 *
 * Auth: pakai GLOBAL API key (`AUTHENTICATION_API_KEY` di Evolution `.env`)
 * lewat header `apikey`. Per-tenant cuma menyimpan `instance` name — semua
 * tenant share 1 server Evolution (cost-efficient untuk MVP).
 *
 * Alternative: per-instance token (field `hash` saat create instance) disimpan
 * di tenants.wa_settings. Lebih aman untuk multi-tenant tapi tiap tenant butuh
 * 1 API call create-instance saat onboarding. Hold off — pakai global dulu.
 *
 * Endpoint: POST {base_url}/message/sendText/{instance}
 * Headers: apikey, Content-Type: application/json
 * Body:    { number: "62xxx", text: "..." }
 * Optional: delay, quoted, linkPreview, mentionsEveryOne, mentioned.
 *
 * Skipped: webhook inbound, sendMedia, sendButtons, presence, group messages.
 * Add when ada permintaan rich-message / balasan WA triggering update status.
 */
class EvolutionService
{
    /**
     * Default template WA per status order. Dipakai kalau tenant belum
     * override di `wa_settings.templates[status]`. Token `{var}` di-substitusi
     * via `renderTemplate()` saat notif fired — `strtr` abaikan token yang
     * gak ada di $vars (unknown token left literal di output).
     *
     * Mirrors previous `buildOrderStatusMessage()` wording supaya tenant
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
    ) {
        $this->baseUrl = $this->baseUrl !== ''
            ? $this->baseUrl
            : (string) config('services.evolution.base_url', '');
        $this->apiKey  = $this->apiKey !== ''
            ? $this->apiKey
            : (string) config('services.evolution.api_key', '');
        $this->timeout = $this->timeout > 0
            ? $this->timeout
            : (int) config('services.evolution.timeout', 15);
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
     * Buat instance baru (opsional — kalau owner belum punya WA number).
     *
     * POST {base_url}/instance/create
     * Body: {
     *   instanceName, number, integration: "WHATSAPP-BAILEYS",
     *   // optional: qrcode, webhook, etc — lihat Evolution docs
     * }
     *
     * `integration: WHATSAPP-BAILEYS` WAJIB — tanpa field ini Evolution
     * return 400 "Invalid integration" (tested 2026-07-16).
     *
     * Response berisi { hash: "instance-token", instance: {...}, ... }.
     * `hash` adalah per-instance token — kalau mau swap global→per-instance
     * auth di kemudian hari, simpan ini di tenants.wa_settings.
     */
    public function createInstance(string $name, string $number): array
    {
        $this->assertConfigured();
        $number = $this->normalizePhone($number);

        $response = Http::withHeaders(['apikey' => $this->apiKey])
            ->timeout($this->timeout)
            ->acceptJson()
            ->asJson()
            ->post("{$this->baseUrl}/instance/create", [
                'instanceName' => $name,
                'number'       => $number,
                'integration'  => 'WHATSAPP-BAILEYS',
            ]);

        $this->assertSuccess($response, "create instance '{$name}'");

        return $response->json() ?? [];
    }

    /**
     * Logout instance (putuskan sesi WA di-HP owner, instance tetap ada di
     * Evolution untuk re-pair nanti). Untuk benar-benar hapus instance pakai
     * `deleteInstance`.
     *
     * DELETE {base_url}/instance/logout/{instance}
     * Response 200: { status: "SUCCESS", error: false, response: { message: "Instance logged out" } }
     *
     * Flow: owner tap "Reset Koneksi" di mobile → controller panggil ini →
     * instance jadi state=close di Evolution (tapi `instance` row tetap).
     * Setelah itu mobile re-call /wa-pairing untuk dapat pairing code baru.
     */
    public function logoutInstance(string $instance): array
    {
        $this->assertConfigured();

        $response = Http::withHeaders(['apikey' => $this->apiKey])
            ->timeout($this->timeout)
            ->delete("{$this->baseUrl}/instance/logout/{$instance}");

        // Idempotent cases — treat sebagai sukses karena target state
        // (logout) sudah tercapai:
        // - 404: instance udah ga ada (pernah di-delete manual / auto-cleanup)
        // - 400 "is not connected": instance ada tapi state=close, udah
        //   logout duluan (race dengan user yg manual logout di WA HP).
        if ($response->status() === 404) {
            return ['status' => 'SUCCESS', 'already_absent' => true];
        }
        if ($response->status() === 400) {
            $body = $response->json();
            $msg = $body['response']['message'][0] ?? $body['message'] ?? '';
            if (str_contains(strtolower((string) $msg), 'not connected')) {
                return ['status' => 'SUCCESS', 'already_disconnected' => true];
            }
        }

        $this->assertSuccess($response, "logout instance '{$instance}'");

        return $response->json() ?? [];
    }

    /**
     * Cek status koneksi instance (connected | disconnected | connecting).
     * Berguna untuk badge status di UI Tenant Settings.
     *
     * GET {base_url}/instance/connectionState/{instance}
     */
    public function connectionState(string $instance): array
    {
        $this->assertConfigured();

        $response = Http::withHeaders(['apikey' => $this->apiKey])
            ->timeout($this->timeout)
            ->get("{$this->baseUrl}/instance/connectionState/{$instance}");

        $this->assertSuccess($response, "check instance '{$instance}'");

        return $response->json() ?? [];
    }

    /**
     * Generate pairing code (8-char) untuk link WhatsApp via phone,
     * bukan QR scan. Owner input manual di WA → Settings → Linked Devices
     * → "Link with phone number".
     *
     * GET {base_url}/instance/connect/{instance}?number={62xxx}
     *
     * Response 200: { pairingCode: "WZYEH1YY", code: "<base64>", count: 1 }
     * - `pairingCode` = yang ditampilkan ke user (8-char, case-sensitive)
     * - `code` = blob QR (untuk fallback QR scan)
     * - 404: instance tidak ditemukan (typo / belum dibuat)
     *
     * @param  string  $number  nomor owner dgn country code, no '+'
     * @return array{ pairingCode: string, code: ?string, count: ?int }
     */
    public function pairingCode(string $instance, string $number): array
    {
        $this->assertConfigured();
        $number = $this->normalizePhone($number);

        $response = Http::withHeaders(['apikey' => $this->apiKey])
            ->timeout($this->timeout)
            ->get("{$this->baseUrl}/instance/connect/{$instance}", [
                'number' => $number,
            ]);

        $this->assertSuccess($response, "get pairing code for '{$instance}'");

        return $response->json() ?? [];
    }

    /**
     * Kirim text message via endpoint Evolution API v2.
     *
     * POST {base_url}/message/sendText/{instance}
     * Body: { number, text }
     *
     * `number` harus digits-only, country code included, NO '+'.
     *   Ex: Indonesia 0812-3456-7890 → "6281234567890"
     *
     * @throws RuntimeException kalau HTTP gagal / nomor invalid
     */
    public function sendText(string $instance, string $phone, string $message): array
    {
        $this->assertConfigured();
        $number = $this->normalizePhone($phone);

        $response = Http::withHeaders(['apikey' => $this->apiKey])
            ->timeout($this->timeout)
            ->acceptJson()
            ->asJson()
            ->post("{$this->baseUrl}/message/sendText/{$instance}", [
                'number' => $number,
                'text'   => $message,
            ]);

        $this->assertSuccess($response, "send to '{$number}' via '{$instance}'");

        return $response->json() ?? [];
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
     * Generate nama instance Evolution otomatis untuk tenant ini.
     *
     * Format: `LaundryAja-{nomor_hp_normalized}{tenant_id}`
     *
     * - Prefix brand `LaundryAja-`
     * - Nomor HP owner dalam format internasional (62xxx, no '+')
     *   yang sudah di-normalize via normalizePhone()
     * - Suffix tenant_id (numeric) supaya unik kalau nomor owner
     *   kebetulan sama antar tenant (edge case: 1 owner punya multi-tenant)
     *
     * Karakter valid Evolution: `[A-Za-z0-9_-]+`. Contoh hasil:
     *   tenant 3, nomor "081234567890" → "LaundryAja-62812345678903"
     *
     * Dipakai saat owner pertama kali setup WA gateway — mobile tidak
     * perlu input nama instance lagi. Untuk idempotent, controller
     * pairing cek dulu `tenants.wa_settings.instance` sebelum generate.
     */
    public static function generateInstanceName(string $phone, int $tenantId): string
    {
        $instance = new self();
        $digits = $instance->normalizePhone($phone);
        return "LaundryAja-{$digits}{$tenantId}";
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
     * Susun pesan notifikasi. Template minimal — Blade view saat ada variabel
     * tambahan (estimasi biaya, link tracking, dsb).
     *
     * @deprecated Sejak template per tenant, prefer `renderForTenant()`.
     * Method ini tetap ada untuk backward compat (test/legacy caller).
     */
    public static function buildOrderStatusMessage(
        string $tenantName,
        string $ticketNumber,
        string $statusLabel,
        ?string $notes = null,
    ): string {
        $msg = "Halo, laundry Anda di *{$tenantName}* (tiket *{$ticketNumber}*) "
            . "sekarang berstatus: *{$statusLabel}*.";

        if ($notes) {
            $msg .= "\nCatatan: {$notes}";
        }

        return $msg;
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
     * Token yang gak ada di $vars left literal — caller harus declare
     * semua variable yang dipakai template (lihat OrderService::maybeNotifyWa).
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

    /**
     * Guard: gagal awal kalau env Evolution belum di-set.
     */
    private function assertConfigured(): void
    {
        if (!$this->isConfigured()) {
            throw new RuntimeException(
                'Evolution API belum dikonfigurasi (EVOLUTION_API_URL / EVOLUTION_API_KEY kosong).'
            );
        }
    }

    /**
     * Throw kalau response bukan 2xx. Pesan error membawa HTTP status + body
     * ringkas (max 500 char supaya tidak menuhin log).
     */
    private function assertSuccess(Response $response, string $context): void
    {
        if ($response->successful()) {
            return;
        }

        $body = $response->body();
        if (strlen($body) > 500) {
            $body = substr($body, 0, 500) . '... (truncated)';
        }

        // Pesan error paling umum (dari pengalaman issue tracker):
        // 401 — api_key salah
        // 403 — instance tidak diizinkan utk key ini
        // 404 — instance name tidak ditemukan / belum dibuat
        // 422 — nomor invalid / parameter kurang
        // 500 — Evolution internal error (biasanya transient, retry helps)
        throw new RuntimeException(sprintf(
            'Evolution API %s gagal [%d]: %s',
            $context,
            $response->status(),
            $body ?: '(empty body)'
        ));
    }
}
