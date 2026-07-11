<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class IconRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() && in_array($this->user()->role, ['owner', 'super_admin'], true);
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'is_active' => $this->boolean('is_active', true),
        ]);
    }

    public function rules(): array
    {
        $isUpdate = $this->isMethod('PUT') || $this->isMethod('PATCH');

        return [
            // `name` adalah label internal (mis. "Cuci Kering"). Backend
            // tidak pakai name untuk display; frontend pakai image.
            'name'      => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:100'],
            // Upload icon. Pada update: opsional (replace file).
            // image|max:1024 = max 1 MB, lebih dari itu tolak agar storage
            // tidak bengkak untuk icon 24x24.
            'icon'      => [$isUpdate ? 'nullable' : 'required', 'file', 'image', 'max:1024'],
            'is_active' => ['boolean'],
        ];
    }
}