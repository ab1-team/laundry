<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AppVersionRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Hanya super_admin — middleware 'role:super_admin' di route sudah
        // memfilter, tapi authorize() di sini jadi pengaman kedua kalau
        // controller dipanggil dari tempat lain.
        return $this->user() && $this->user()->role === 'super_admin';
    }

    public function rules(): array
    {
        $isUpdate = $this->isMethod('PUT') || $this->isMethod('PATCH');

        return [
            'version'      => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:30'],
            'version_code' => [$isUpdate ? 'sometimes' : 'required', 'integer', 'min:1'],
            'min_version'  => ['nullable', 'string', 'max:30'],
            'force_update' => ['boolean'],
            'changelog'    => ['nullable', 'string', 'max:5000'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'force_update' => $this->boolean('force_update', false),
        ]);
    }
}