<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class ChangePasswordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        $user = $this->user();

        return [
            'current_password' => [
                'required',
                'string',
                function (string $attribute, mixed $value, \Closure $fail) use ($user) {
                    if (! $user || ! Hash::check((string) $value, $user->password)) {
                        $fail('Password lama tidak sesuai.');
                    }
                },
            ],
            'password' => [
                'required',
                'string',
                'min:8',
                'confirmed',
                Rule::notIn([$this->input('current_password')]),
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'current_password.required' => 'Password lama wajib diisi',
            'password.required'         => 'Password baru wajib diisi',
            'password.min'              => 'Password baru minimal 8 karakter',
            'password.confirmed'        => 'Konfirmasi password tidak cocok',
            'password.not_in'           => 'Password baru harus berbeda dengan password lama',
        ];
    }
}
