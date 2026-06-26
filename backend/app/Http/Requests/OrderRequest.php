<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class OrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        $tenantId = $this->user()->tenant_id ?? 0;

        return [
            'customer_id' => [
                'required',
                'integer',
                Rule::exists('customers', 'id')->where('tenant_id', $tenantId),
            ],
            'notes'       => ['nullable', 'string'],
            'discount'    => ['nullable', 'numeric', 'min:0'],
            'items'              => ['required', 'array', 'min:1'],
            'items.*.service_id' => [
                'required',
                'integer',
                Rule::exists('services', 'id')->where('tenant_id', $tenantId),
            ],
            'items.*.qty'        => ['required', 'numeric', 'min:0.01'],
        ];
    }

    public function messages(): array
    {
        return [
            'customer_id.required'     => 'Customer wajib dipilih',
            'items.required'           => 'Order minimal 1 item',
            'items.*.service_id.required' => 'Service wajib dipilih',
            'items.*.qty.required'     => 'Qty wajib diisi',
            'items.*.qty.min'          => 'Qty minimal 0.01',
        ];
    }
}