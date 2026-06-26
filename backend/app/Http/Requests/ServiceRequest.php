<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ServiceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() && in_array($this->user()->role, ['owner', 'super_admin'], true);
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'is_active'      => $this->boolean('is_active', true),
            'duration_hours' => $this->input('duration_hours', 24),
        ]);
    }

    public function rules(): array
    {
        $isUpdate = $this->isMethod('PUT') || $this->isMethod('PATCH');

        return [
            'category_id'    => [
                $isUpdate ? 'sometimes' : 'required',
                'integer',
                Rule::exists('service_categories', 'id')->where('tenant_id', $this->user()->tenant_id ?? 0),
            ],
            'name'           => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:150'],
            'price'          => [$isUpdate ? 'sometimes' : 'required', 'numeric', 'min:0'],
            'unit'           => [$isUpdate ? 'sometimes' : 'required', 'string', 'max:30'],
            'duration_hours' => ['integer', 'min:1'],
            'is_active'      => ['boolean'],
        ];
    }
}
