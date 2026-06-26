# Struktur Database — SaaS Laundry Management (Multi-Tenant)

Database: MySQL 8  
Strategi: Single database, shared tables, isolasi via `tenant_id`  
Timestamps default: `created_at`, `updated_at` (semua tabel kecuali log)

---

## Catatan Arsitektur

Semua tabel yang merupakan data tenant memiliki kolom `tenant_id` (FK ke `tenants.id`). Laravel Global Scope `BelongsToTenant` otomatis menyisipkan `WHERE tenant_id = ?` di setiap query model yang menggunakan trait tersebut.

Tabel yang **tidak** memiliki `tenant_id`: `tenants`, `super_admins`, `otp_codes`.

---

## Tabel: `tenants`

Dikelola oleh Super Admin. Satu baris = satu outlet/vendor laundry.

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `name` | VARCHAR(150) | Nama outlet |
| `slug` | VARCHAR(100) UNIQUE | Subdomain / kode unik tenant |
| `phone` | VARCHAR(20) NULLABLE | Nomor WA outlet |
| `address` | TEXT NULLABLE | Alamat outlet |
| `city` | VARCHAR(100) NULLABLE | |
| `logo` | VARCHAR(255) NULLABLE | Path logo |
| `status` | ENUM('active','suspended','trial') DEFAULT 'trial' | |
| `trial_ends_at` | TIMESTAMP NULLABLE | |
| `activated_at` | TIMESTAMP NULLABLE | |

---

## Tabel: `users`

Pengguna aplikasi: Owner & Operator tiap tenant, plus Super Admin (tenant_id NULL).

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id NULLABLE | NULL = Super Admin |
| `name` | VARCHAR(100) | |
| `email` | VARCHAR(150) UNIQUE | |
| `password` | VARCHAR(255) | |
| `role` | ENUM('super_admin','owner','operator') | |
| `is_active` | TINYINT(1) DEFAULT 1 | |
| `last_login_at` | TIMESTAMP NULLABLE | |

---

## Tabel: `service_categories`

Kategori layanan milik tenant (bisa juga di-seed default oleh platform).

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `name` | VARCHAR(100) | Contoh: Kiloan, Satuan, Express, Sepatu |
| `icon` | VARCHAR(100) NULLABLE | Nama icon (opsional) |
| `sort_order` | TINYINT DEFAULT 0 | Urutan tampil |
| `is_active` | TINYINT(1) DEFAULT 1 | |

---

## Tabel: `services`

Layanan & harga spesifik per tenant.

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `category_id` | FK → service_categories.id | |
| `name` | VARCHAR(150) | Contoh: Cuci Kering, Cuci Setrika |
| `price` | DECIMAL(12,2) | Harga per unit |
| `unit` | VARCHAR(30) | Contoh: kg, pcs, pasang |
| `duration_hours` | INT DEFAULT 24 | Estimasi waktu proses (jam) |
| `is_active` | TINYINT(1) DEFAULT 1 | |

---

## Tabel: `customers`

Data customer yang dicatat oleh operator. Tidak punya akses login.

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `name` | VARCHAR(100) | |
| `phone` | VARCHAR(20) NULLABLE | Nomor WA untuk notifikasi |
| `address` | TEXT NULLABLE | |
| `notes` | TEXT NULLABLE | Catatan internal (VIP, alergi bahan, dll) |
| `total_orders` | INT DEFAULT 0 | Cached counter |
| `total_spent` | DECIMAL(14,2) DEFAULT 0 | Cached total transaksi |

> Index: `UNIQUE(tenant_id, phone)` — satu nomor WA unik per tenant.

---

## Tabel: `orders`

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `customer_id` | FK → customers.id | |
| `created_by` | FK → users.id | Operator yang input |
| `ticket_number` | VARCHAR(30) UNIQUE | Format: LND-YYYYMMDD-XXXX |
| `notes` | TEXT NULLABLE | Catatan untuk cucian ini |
| `status` | ENUM('masuk','dicuci','selesai','diambil','dibatalkan') DEFAULT 'masuk' | |
| `subtotal` | DECIMAL(12,2) | |
| `discount` | DECIMAL(12,2) DEFAULT 0 | |
| `total` | DECIMAL(12,2) | |
| `estimated_finish_at` | TIMESTAMP NULLABLE | |
| `finished_at` | TIMESTAMP NULLABLE | |
| `picked_up_at` | TIMESTAMP NULLABLE | |
| `cancelled_at` | TIMESTAMP NULLABLE | |
| `cancel_reason` | TEXT NULLABLE | |

---

## Tabel: `order_items`

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `order_id` | FK → orders.id | |
| `service_id` | FK → services.id | |
| `service_name` | VARCHAR(150) | Snapshot nama saat order dibuat |
| `unit` | VARCHAR(30) | Snapshot unit |
| `price` | DECIMAL(12,2) | Snapshot harga |
| `qty` | DECIMAL(8,2) | |
| `subtotal` | DECIMAL(12,2) | price × qty |

---

## Tabel: `order_status_logs`

Riwayat perubahan status order.

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `order_id` | FK → orders.id | |
| `status` | VARCHAR(50) | Status baru |
| `note` | TEXT NULLABLE | |
| `changed_by` | FK → users.id | |
| `created_at` | TIMESTAMP | Tidak ada updated_at |

---

## Tabel: `payments`

Pencatatan pembayaran per order. Tidak terintegrasi payment gateway — dicatat manual oleh operator.

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `order_id` | FK → orders.id | |
| `amount` | DECIMAL(12,2) | Jumlah yang dibayarkan |
| `method` | ENUM('cash','transfer','qris','lainnya') | |
| `note` | VARCHAR(255) NULLABLE | Contoh: "Transfer BCA jam 14:00" |
| `paid_at` | TIMESTAMP | Waktu pembayaran |
| `recorded_by` | FK → users.id | Operator yang catat |

> Satu order bisa memiliki beberapa baris payment (DP → pelunasan).  
> Status lunas/hutang dihitung dari `SUM(payments.amount)` vs `orders.total`.

---

## Tabel: `wa_notifications`

Log pengiriman notifikasi WA ke customer (opsional, jika Evolution API aktif).

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `id` | BIGINT UNSIGNED PK | |
| `tenant_id` | FK → tenants.id | |
| `order_id` | FK → orders.id NULLABLE | |
| `customer_id` | FK → customers.id NULLABLE | |
| `phone` | VARCHAR(20) | Nomor tujuan |
| `message` | TEXT | Pesan yang dikirim |
| `status` | ENUM('pending','sent','failed') DEFAULT 'pending' | |
| `sent_at` | TIMESTAMP NULLABLE | |
| `error` | TEXT NULLABLE | Pesan error jika gagal |

---

## Relasi Ringkas

```
tenants ──< users (owner, operator)
        ──< service_categories ──< services
        ──< customers ──< orders ──< order_items ──> services
                               ──< order_status_logs
                               ──< payments
                               ──< wa_notifications
```

---

## Index yang Direkomendasikan

```sql
-- Order queries (paling sering diakses)
CREATE INDEX idx_orders_tenant_status   ON orders(tenant_id, status);
CREATE INDEX idx_orders_tenant_customer ON orders(tenant_id, customer_id);
CREATE INDEX idx_orders_tenant_date     ON orders(tenant_id, created_at);

-- Customer lookup per tenant
CREATE UNIQUE INDEX idx_customers_tenant_phone ON customers(tenant_id, phone);
CREATE INDEX idx_customers_tenant_name         ON customers(tenant_id, name);

-- Payment summary per order
CREATE INDEX idx_payments_order ON payments(order_id);

-- Status log per order
CREATE INDEX idx_status_log_order ON order_status_logs(order_id);

-- WA notification queue
CREATE INDEX idx_wa_notif_status ON wa_notifications(status, tenant_id);
```

---

## Catatan Implementasi BelongsToTenant

```php
// app/Traits/BelongsToTenant.php
trait BelongsToTenant
{
    protected static function bootBelongsToTenant(): void
    {
        static::addGlobalScope('tenant', function (Builder $query) {
            if (auth()->check() && auth()->user()->tenant_id) {
                $query->where('tenant_id', auth()->user()->tenant_id);
            }
        });

        static::creating(function ($model) {
            if (auth()->check() && auth()->user()->tenant_id) {
                $model->tenant_id = auth()->user()->tenant_id;
            }
        });
    }
}
```

Gunakan trait ini di semua model yang memiliki `tenant_id`: `Customer`, `Order`, `OrderItem`, `Service`, `ServiceCategory`, `Payment`, `WaNotification`, `OrderStatusLog`.
