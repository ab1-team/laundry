<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        $isUpdate = $this->isMethod('PUT') || $this->isMethod('PATCH');
        $tenantId = $this->user()->tenant_id ?? 0;
        $ignoreId = $this->route('customer')?->id;

        return [
            'name'    => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:100'],
            'phone'   => [
                'nullable',
                'string',
                'max:20',
                Rule::unique('customers', 'phone')
                    ->where('tenant_id', $tenantId)
                    ->ignore($ignoreId),
            ],
            'address' => ['nullable', 'string'],
            'notes'   => ['nullable', 'string'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required'  => 'Nama customer wajib diisi',
            'phone.unique'   => 'Nomor telepon sudah terdaftar di tenant ini',
        ];
    }
}
