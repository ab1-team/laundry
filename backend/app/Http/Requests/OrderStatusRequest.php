<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class OrderStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'status'        => ['required', Rule::in([
                \App\Models\Order::STATUS_DICUCI,
                \App\Models\Order::STATUS_SELESAI,
                \App\Models\Order::STATUS_DIAMBIL,
                \App\Models\Order::STATUS_DIBATALKAN,
            ])],
            'note'          => ['nullable', 'string'],
            'cancel_reason' => ['nullable', 'string', 'required_if:status,dibatalkan'],
        ];
    }
}