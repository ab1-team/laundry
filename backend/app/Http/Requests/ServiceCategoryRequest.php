<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

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
            'icon'       => ['nullable', 'string', 'max:100'],
            'sort_order' => ['integer'],
            'is_active'  => ['boolean'],
        ];
    }
}
