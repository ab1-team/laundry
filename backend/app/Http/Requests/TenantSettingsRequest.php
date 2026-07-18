<?php

namespace App\Http\Requests;

use App\Models\Order;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class TenantSettingsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() && in_array($this->user()->role, ['owner', 'super_admin'], true);
    }

    public function rules(): array
    {
        $tenant = $this->user()->tenant;
        $ignoreId = $tenant?->id;

        return [
            'name'    => ['sometimes', 'string', 'max:150'],
            'phone'   => ['nullable', 'string', 'max:20'],
            'address' => ['nullable', 'string'],
            'city'    => ['nullable', 'string', 'max:100'],
            // Terima upload gambar logo (jpg/jpeg/png/webp, max 2MB).
            // Client mengirim field multipart 'logo'.
            'logo'    => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'slug'    => [
                'sometimes',
                'string',
                'max:100',
                'alpha_dash',
                Rule::unique('tenants', 'slug')->ignore($ignoreId),
            ],

            // WA (Evolution API) gateway settings — per-tenant.
            // Boleh null (nonaktifkan) atau object { enabled, instance, notify_on, templates }.
            // Validasi: instance name alphanumeric+_- (sesuai Evolution).
            'wa_settings'                     => ['sometimes', 'nullable', 'array'],
            'wa_settings.enabled'             => ['sometimes', 'boolean'],
            'wa_settings.instance'            => ['sometimes', 'nullable', 'string', 'max:100', 'regex:/^[A-Za-z0-9_\-]+$/'],
            'wa_settings.notify_on'           => ['sometimes', 'array'],
            'wa_settings.notify_on.*'         => ['string', 'in:masuk,dicuci,selesai,diambil,dibatalkan'],
            // Custom WA template per status — key harus salah satu status order
            // yang dikenal. Value string max 1000 char. Empty string diizinkan
            // (akan difilter ke default di renderForTenant).
            'wa_settings.templates'           => ['sometimes', 'nullable', 'array'],
            'wa_settings.templates.*'         => ['nullable', 'string', 'max:1000'],
        ];
    }

    /**
     * Key whitelist `wa_settings.templates` — cegah typo key (mis. "selesaii")
     * nyelinap ke DB dan gak pernah di-render (silent failure). Whitelist =
     * konstanta status Order.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $v) {
            $templates = $this->input('wa_settings.templates');
            if (!is_array($templates)) {
                return;
            }
            $allowed = [
                Order::STATUS_MASUK,
                Order::STATUS_DICUCI,
                Order::STATUS_SELESAI,
                Order::STATUS_DIAMBIL,
                Order::STATUS_DIBATALKAN,
            ];
            $invalid = array_keys(array_diff_key($templates, array_flip($allowed)));
            if ($invalid !== []) {
                $v->errors()->add(
                    'wa_settings.templates',
                    'Key template tidak dikenal: ' . implode(', ', $invalid)
                        . '. Pakai salah satu: ' . implode(', ', $allowed) . '.',
                );
            }
        });
    }

    public function messages(): array
    {
        return [
            'logo.image' => 'Logo harus berupa file gambar',
            'logo.mimes' => 'Format logo harus jpg, jpeg, png, atau webp',
            'logo.max'   => 'Ukuran logo maksimal 2MB',
        ];
    }
}
