<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterTenantRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Tenant
            'name'     => ['required', 'string', 'max:150'],
            'slug'     => ['required', 'string', 'max:100', 'alpha_dash', Rule::unique('tenants', 'slug')],
            'phone'    => ['nullable', 'string', 'max:20'],
            'address'  => ['nullable', 'string'],
            'city'     => ['nullable', 'string', 'max:100'],

            // Owner
            'owner_name'     => ['required', 'string', 'max:100'],
            'owner_email'    => ['required', 'email', Rule::unique('users', 'email')],
            'owner_password' => ['required', 'string', 'min:6', 'confirmed'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required'             => 'Nama outlet wajib diisi',
            'slug.required'             => 'Slug wajib diisi',
            'slug.unique'               => 'Slug sudah digunakan',
            'slug.alpha_dash'           => 'Slug hanya boleh huruf, angka, dash, underscore',
            'owner_name.required'       => 'Nama owner wajib diisi',
            'owner_email.required'      => 'Email owner wajib diisi',
            'owner_email.email'         => 'Format email owner tidak valid',
            'owner_email.unique'        => 'Email owner sudah digunakan',
            'owner_password.required'   => 'Password wajib diisi',
            'owner_password.min'        => 'Password minimal 6 karakter',
            'owner_password.confirmed'  => 'Konfirmasi password tidak cocok',
        ];
    }
}