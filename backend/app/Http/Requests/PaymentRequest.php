<?php

namespace App\Http\Requests;

use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'amount'   => ['required', 'numeric', 'min:1'],
            'method'   => ['required', Rule::in([
                \App\Models\Payment::METHOD_CASH,
                \App\Models\Payment::METHOD_TRANSFER,
                \App\Models\Payment::METHOD_QRIS,
                \App\Models\Payment::METHOD_LAINNYA,
            ])],
            'note'     => ['nullable', 'string', 'max:255'],
            'paid_at'  => ['nullable', 'date'],
        ];
    }

    public function messages(): array
    {
        return [
            'amount.required' => 'Jumlah pembayaran wajib diisi',
            'amount.min'      => 'Jumlah minimal 1',
            'method.required' => 'Metode pembayaran wajib dipilih',
        ];
    }
}