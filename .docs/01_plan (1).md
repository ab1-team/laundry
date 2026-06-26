# Plan Aplikasi SaaS Manajemen Laundry (Multi-Tenant)

## Overview

Aplikasi SaaS untuk membantu vendor laundry dalam mengelola operasional sehari-hari: pencatatan order, tracking status cucian, manajemen customer, transaksi, dan laporan. Setiap vendor adalah tenant yang memiliki data terisolasi. Customer tidak memiliki akses ke aplikasi — hanya dicatat sebagai data oleh operator vendor.

---

## Model Tenancy

- **Strategi**: Single database, shared tables dengan kolom `tenant_id`
- **Identifikasi tenant**: subdomain (`namatoko.laundryapp.com`) atau kode unik tenant
- **Isolasi data**: semua query di-scope otomatis via `tenant_id` (Global Scope Laravel)
- **Library**: tidak perlu Stancl Tenancy — cukup trait `BelongsToTenant` custom

---

## Aktor & Role

| Role | Deskripsi |
|------|-----------|
| **Super Admin** | Pengelola platform (SaaS owner), manage semua tenant |
| **Tenant Owner** | Pemilik outlet laundry, akses penuh ke data tenant-nya |
| **Operator** | Karyawan outlet, input order & update status harian |

> Customer **bukan** user aplikasi. Mereka hanya dicatat sebagai data kontak & riwayat order.

---

## Modul Aplikasi

### 1. Tenant Management *(Super Admin only)*
- Daftar & kelola tenant (buat, aktifkan, suspend)
- Set paket/plan per tenant (opsional: fitur berbeda per plan)
- Monitoring usage

### 2. Auth & User Management
- Login per tenant (scope ke tenant masing-masing)
- Multi-role dalam satu tenant: Owner, Operator
- Manajemen akun operator oleh Owner

### 3. Master Data
- Kategori layanan (kiloan, satuan, express, dll)
- Daftar layanan & harga milik tenant
- Pengaturan outlet (nama, alamat, nomor WA, logo)

### 4. Manajemen Customer
- CRUD data customer (nama, nomor WA/HP, alamat)
- Riwayat order per customer
- Catatan/label customer (VIP, blacklist, dll) — opsional

### 5. Order Management
- Buat order baru: pilih customer, pilih layanan, input qty, catatan
- Nomor tiket / kode order otomatis
- Estimasi selesai otomatis berdasarkan layanan
- Daftar order aktif & riwayat order
- Filter & pencarian order

### 6. Tracking Status
- Pipeline status: `masuk` → `dicuci` → `selesai` → `diambil`
- Update status oleh operator
- Log riwayat perubahan status per order
- Notifikasi WA ke customer saat status berubah (opsional, via Evolution API / WA gateway)

### 7. Transaksi & Pembayaran
- Kalkulasi total otomatis dari item order
- Pencatatan pembayaran: lunas / DP / hutang
- Metode bayar: cash, transfer, QRIS (dicatat manual, bukan gateway)
- Riwayat transaksi

### 8. Laporan
- Ringkasan pendapatan harian / mingguan / bulanan
- Order per layanan (layanan paling laris)
- Piutang customer (order belum lunas)
- Export PDF / CSV

---

## Tech Stack

### Backend
- **Framework**: Laravel 11+
- **Database**: MySQL 8 (single DB, shared tables)
- **Auth**: Laravel Sanctum
- **Multi-tenant scope**: Custom `BelongsToTenant` Global Scope
- **Queue**: Laravel Queue (Redis) — untuk notifikasi WA async
- **Storage**: MinIO / S3-compatible — untuk logo & lampiran
- **Notifikasi WA**: Evolution API + n8n (opsional)

### Frontend / Mobile
- **Mobile**: Flutter (untuk operator & owner di lapangan)
- **Web admin panel**: Bisa Flutter Web atau Next.js (untuk Super Admin)
- **State Management**: Riverpod / BLoC
- **HTTP Client**: Dio

### Infrastructure
- **Server**: VPS AlmaLinux
- **Web Server**: Nginx + PHP-FPM
- **Container**: Docker Compose
- **CI/CD**: GitHub Actions

---

## Alur Kerja Utama (Happy Path)

```
Operator buka aplikasi (login sebagai tenant)
    → Pilih / cari customer (atau buat baru)
    → Buat order: pilih layanan, input qty, catatan
    → Sistem generate nomor tiket & estimasi selesai
    → Pembayaran dicatat (lunas / DP / hutang)
    → [Opsional] Notifikasi WA otomatis ke customer
    → Operator update status saat cucian diproses
    → Status selesai → [Opsional] WA notifikasi ke customer
    → Customer ambil, status jadi "diambil"
    → Transaksi close
```
