<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ServiceCategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() && in_array($this->user()->role, ['owner', 'super_admin'], true);
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'is_active'  => $this->boolean('is_active', true),
            'sort_order' => $this->input('sort_order', 0),
        ]);
    }

    public function rules(): array
    {
        $isUpdate = $this->isMethod('PUT') || $this->isMethod('PATCH');

        return [
            'name'       => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:100'],
            // FK ke tabel icons. NullOnDelete di migration: kalau icon
            // dihapus, kategori.icon_id otomatis jadi null.
            'icon_id'    => ['nullable', 'integer', Rule::exists('icons', 'id')->where('tenant_id', $this->user()->tenant_id ?? 0)],
            'sort_order' => ['integer'],
            'is_active'  => ['boolean'],
        ];
    }
}
