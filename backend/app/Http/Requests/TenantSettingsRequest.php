<?php

namespace App\Http\Requests;

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
        ];
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
