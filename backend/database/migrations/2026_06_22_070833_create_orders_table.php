<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained('customers')->restrictOnDelete();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->string('ticket_number', 30)->unique();
            $table->text('notes')->nullable();
            $table->enum('status', ['masuk', 'dicuci', 'selesai', 'diambil', 'dibatalkan'])->default('masuk');
            $table->decimal('subtotal', 12, 2);
            $table->decimal('discount', 12, 2)->default(0);
            $table->decimal('total', 12, 2);
            $table->timestamp('estimated_finish_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->text('cancel_reason')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'status'], 'idx_orders_tenant_status');
            $table->index(['tenant_id', 'customer_id'], 'idx_orders_tenant_customer');
            $table->index(['tenant_id', 'created_at'], 'idx_orders_tenant_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
