<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('name', 100);
            $table->string('phone', 20)->nullable();
            $table->text('address')->nullable();
            $table->text('notes')->nullable();
            $table->unsignedInteger('total_orders')->default(0);
            $table->decimal('total_spent', 14, 2)->default(0);
            $table->timestamps();

            $table->unique(['tenant_id', 'phone'], 'idx_customers_tenant_phone');
            $table->index(['tenant_id', 'name'], 'idx_customers_tenant_name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
