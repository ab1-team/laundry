<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class WaPairingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() && in_array($this->user()->role, ['owner', 'super_admin'], true);
    }

    public function rules(): array
    {
        return [
            // Nomor owner yg akan menerima pairing code. Boleh format apa saja
            // (08xx, +62xx, 62xx) — EvolutionService::normalizePhone() yg handle.
            'number' => ['required', 'string', 'min:8', 'max:20'],
        ];
    }
}
