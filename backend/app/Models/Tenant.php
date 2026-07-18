<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Tenant extends Model
{

    protected $fillable = [
        'name',
        'slug',
        'phone',
        'address',
        'city',
        'logo_path',
        'status',
        'trial_ends_at',
        'activated_at',
        'wa_settings',
    ];

    protected function casts(): array
    {
        return [
            'trial_ends_at'  => 'datetime',
            'activated_at'   => 'datetime',
            // JSON cast — `wa_settings` adalah payload opt-in/opt-out
            // notifikasi WA per-tenant. Default kosong (fitur off).
            'wa_settings'    => 'array',
        ];
    }

    /**
     * Helper: apakah tenant ini mengaktifkan notifikasi WA.
     * Form tenant::wa_settings default-nya null (fitur off).
     * Cek: enabled=true DAN instance_name terisi.
     */
    public function waEnabled(): bool
    {
        $settings = $this->wa_settings ?? [];

        return (bool) ($settings['enabled'] ?? false)
            && !empty($settings['instance']);
    }

    /**
     * Daftar status order yang memicu notif. Default: masuk (order baru),
     * selesai (siap diambil), diambil — tiga milestone utama yang customer
     * ingin tahu. Tenant yang sudah customize di-settings sebelumnya
     * `wa_settings.notify_on` keep their setting; default hanya untuk
     * tenant baru / yang belum pernah setup.
     */
    public function waNotifyOn(): array
    {
        $settings = $this->wa_settings ?? [];

        return $settings['notify_on'] ?? ['masuk', 'selesai', 'diambil'];
    }

    /**
     * Custom template WA per status (key = status code, value = template string).
     * Dipakai `EvolutionService::renderForTenant()` sebagai override sebelum
     * fallback ke `DEFAULT_TEMPLATES`. Tenant yang gak pernah edit = return [].
     */
    public function waTemplates(): array
    {
        $settings = $this->wa_settings ?? [];

        return is_array($settings['templates'] ?? null)
            ? $settings['templates']
            : [];
    }

    public const STATUS_TRIAL    = 'trial';
    public const STATUS_ACTIVE   = 'active';
    public const STATUS_SUSPENDED = 'suspended';

    /* ---- Relations ---- */

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }
}
