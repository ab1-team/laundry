<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class TenantRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() && $this->user()->isSuperAdmin();
    }

    public function rules(): array
    {
        $tenantId = $this->route('tenant')?->id ?? null;
        $isUpdate = $this->isMethod('PUT') || $this->isMethod('PATCH');
        $isCreate = $this->isMethod('POST');

        return [
            'name'    => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:150'],
            'slug'    => [
                $isUpdate ? 'sometimes' : 'required',
                'string',
                'max:100',
                'alpha_dash',
                Rule::unique('tenants', 'slug')->ignore($tenantId),
            ],
            'phone'   => ['nullable', 'string', 'max:20'],
            'address' => ['nullable', 'string'],
            'city'    => ['nullable', 'string', 'max:100'],
            'logo'    => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
            'status'  => ['nullable', Rule::in(['trial', 'active', 'suspended'])],

            // Owner account — hanya wajib saat create. Saat update, owner
            // dikelola terpisah (bisa tambah operator dll).
            'owner_name'     => [$isCreate ? 'required' : 'nullable', 'string', 'max:150'],
            'owner_email'    => [
                $isCreate ? 'required' : 'nullable',
                'string',
                'email',
                'max:255',
                Rule::unique('users', 'email'),
            ],
            'owner_password' => [$isCreate ? 'required' : 'nullable', 'string', 'min:8'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required'          => 'Nama tenant wajib diisi',
            'slug.unique'            => 'Slug sudah digunakan',
            'owner_name.required'    => 'Nama owner wajib diisi',
            'owner_email.required'   => 'Email owner wajib diisi',
            'owner_email.email'      => 'Format email owner tidak valid',
            'owner_email.unique'     => 'Email owner sudah digunakan',
            'owner_password.required'=> 'Password owner wajib diisi',
            'owner_password.min'     => 'Password owner minimal 8 karakter',
        ];
    }
}