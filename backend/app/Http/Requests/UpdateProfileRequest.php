<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        $user = $this->user();

        return [
            'name'  => ['required', 'string', 'max:150'],
            'email' => [
                'required',
                'string',
                'email',
                'max:255',
                // Email unique di tabel users, tapi abaikan user yang sedang
                // mengedit (supaya dia boleh tetap pakai email lamanya).
                Rule::unique('users', 'email')->ignore($user?->id),
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required'  => 'Nama wajib diisi',
            'name.max'       => 'Nama maksimal 150 karakter',
            'email.required' => 'Email wajib diisi',
            'email.email'    => 'Format email tidak valid',
            'email.unique'   => 'Email sudah digunakan oleh akun lain',
        ];
    }
}