<?php

namespace App\Contracts;

use App\Models\Tenant;

/**
 * Kontrak abstraksi WhatsApp gateway (n8n webhook-test, Evolution API,
 * Twilio, Meta Cloud API, dll).
 *
 * Backend Laravel TIDAK boleh bicara langsung dengan provider spesifik —
 * selalu lewat interface ini. Binding ada di AppServiceProvider::register().
 *
 * Lihat .docs/WA-GATEWAY-API.md untuk endpoint + shape response n8n.
 *
 * Catatan implementasi:
 * - `createInstance(name, number)` menerima phone number supaya provider
 *   bisa auto-generate pairing code via workflow internal (saat ini n8n
 *   yang punya flow ini, lihat Evolution auto-flow).
 * - `sendText(..., ?delayMs)` opsional delay untuk anti-spam detection
 *   WhatsApp — kalau null, implementasi boleh default random 1500-3500ms.
 * - `sendMedia` boleh throw RuntimeException kalau provider belum support
 *   lampiran — caller fallback ke text-only.
 */
interface WhatsAppGateway
{
    /**
     * Apakah credential (base_url + api_key) sudah terisi di env.
     * Pemeriksaan instance per-tenant ada di caller (lihat
     * SendWaNotificationJob → cek wa_settings.instance).
     */
    public function isConfigured(): bool;

    /**
     * Buat instance baru di provider. Wajib return minimal:
     *   ['success' => bool, 'instance' => ['name' => string, 'status' => string, 'qr' => ?string, 'pairingCode' => ?string]]
     *
     * @param  string  $name    nama instance (format app-{slug})
     * @param  string  $number  phone number owner, format bebas (provider yg normalisasi)
     * @return array<string,mixed>
     */
    public function createInstance(string $name, string $number): array;

    /**
     * Cek status koneksi instance.
     *
     * @return array<string,mixed>  minimal: ['success' => bool, 'instance' => ['state' => 'open'|'close'|'connecting']]
     */
    public function connectionState(string $instance): array;

    /**
     * Hapus instance di provider (logout + drop dari server).
     * Idempotent — return success kalau instance sudah tidak ada.
     *
     * @return array<string,mixed>
     */
    public function deleteInstance(string $instance): array;

    /**
     * Minta pairing code baru untuk instance yang sudah ada. Implementasi
     * n8n: delete-instance + create-instance ulang (lihat .docs §1+§3).
     *
     * @param  string $instance  nama instance existing
     * @param  string $number    nomor HP owner (dikirim ulang ke create-instance)
     * @return array<string,mixed>  shape sama dengan createInstance
     */
    public function regeneratePairing(string $instance, string $number): array;

    /**
     * Kirim text message. Boleh return delay yang dipakai untuk audit.
     *
     * @param  string        $instance  nama instance tenant
     * @param  string        $phone     nomor HP tujuan
     * @param  string        $message   body pesan
     * @param  int|null      $delayMs   delay sebelum kirim (anti-spam), null = pakai default
     * @return array<string,mixed>      ['success' => bool, 'delay' => int]
     */
    public function sendText(
        string $instance,
        string $phone,
        string $message,
        ?int $delayMs = null,
    ): array;

    /**
     * Kirim lampiran (PDF/image). Caller (Job) handle fallback ke sendText
     * kalau provider throw RuntimeException dengan pesan "belum support media".
     *
     * @param  string      $mediaPath  path lokal di disk 'local'
     * @param  string      $mime       MIME type
     * @param  string      $fileName   nama file yang tampil di WA
     * @param  string|null $caption    caption optional
     * @return array<string,mixed>
     */
    public function sendMedia(
        string $instance,
        string $phone,
        string $mediaPath,
        string $mime,
        string $fileName,
        ?string $caption = null,
    ): array;

    // ============================================================
    // Pure helpers (shared contract — bukan HTTP call)
    // ============================================================

    /**
     * Normalisasi nomor HP → digits-only dengan country code default 62.
     *
     * Ex: "+62 812-3456-7890" → "6281234567890"
     */
    public function normalizePhone(string $phone): string;

    /**
     * Format tampilan Indonesia: "6281234567890" → "0812-3456-7890".
     */
    public static function formatPhoneId(string $phone): string;

    /**
     * Substitute `{key}` token di $tpl dengan value dari $vars.
     * Pure `strtr` — unknown token left literal (sesuai requirement).
     */
    public static function renderTemplate(string $tpl, array $vars): string;

    /**
     * Pilih template tenant override (wa_settings.templates[status]) kalau
     * ada & non-empty, else fallback ke DEFAULT_TEMPLATES[$status].
     */
    public static function renderForTenant(Tenant $tenant, string $status, array $vars): string;

    /**
     * Generate nama instance otomatis dari phone + tenant_id.
     * Implementasi spesifik per-provider (n8n: `app-{slug}`,
     * Evolution: format lama, dll).
     */
    public static function generateInstanceName(string $phone, int $tenantId): string;
}
