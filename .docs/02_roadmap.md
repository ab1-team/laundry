# Roadmap Pengembangan SaaS Laundry Management

## Fase 1 — Foundation (Minggu 1–3)

**Target**: Project siap, auth jalan, multi-tenant scope aktif.

### Backend
- [ ] Setup project Laravel 11 + Docker Compose
- [ ] Konfigurasi MySQL, Redis, MinIO
- [ ] Design & migrate semua tabel inti
- [ ] Implementasi `BelongsToTenant` Global Scope (auto-inject `tenant_id` di semua query)
- [ ] Tenant identification via subdomain / header
- [ ] Auth API: register tenant, login, logout, refresh token (Sanctum)
- [ ] Multi-role dalam tenant: Owner, Operator
- [ ] API Resource & Response standard (success/error wrapper)
- [ ] Super Admin: CRUD tenant, aktivasi/suspend

### Mobile (Flutter)
- [ ] Setup project + folder structure
- [ ] Konfigurasi Riverpod / BLoC
- [ ] Base HTTP client (Dio + interceptor + tenant header)
- [ ] Auth flow: login, logout
- [ ] Navigasi & routing (go_router)

---

## Fase 2 — Master Data & Customer (Minggu 4–6)

**Target**: Data dasar siap diinput, manajemen customer jalan.

### Backend
- [ ] API layanan: CRUD kategori & layanan + harga per tenant
- [ ] API pengaturan outlet (nama, alamat, WA, logo)
- [ ] API customer: CRUD, list + search, riwayat order

### Mobile
- [ ] Pengaturan outlet (profil tenant)
- [ ] Manajemen layanan & harga
- [ ] Manajemen customer (list, tambah, edit, detail + riwayat)

---

## Fase 3 — Order & Tracking (Minggu 7–11)

**Target**: Fitur inti jalan end-to-end.

### Backend
- [ ] API order: buat order, list, detail, update status
- [ ] Generate nomor tiket otomatis (format: LND-YYYYMMDD-XXXX)
- [ ] Kalkulasi total otomatis dari order items
- [ ] Pipeline status: `masuk` → `dicuci` → `selesai` → `diambil`
- [ ] Log perubahan status per order
- [ ] Filter & pencarian order (status, tanggal, customer)

### Mobile
- [ ] Form buat order (pilih customer, layanan, qty, catatan)
- [ ] Daftar order aktif (dikelompokkan per status)
- [ ] Detail order + timeline status
- [ ] Update status order oleh operator
- [ ] Riwayat order (selesai & dibatalkan)

---

## Fase 4 — Transaksi & Pembayaran (Minggu 12–14)

**Target**: Pencatatan keuangan lengkap.

### Backend
- [ ] API transaksi: catat pembayaran, update status bayar
- [ ] Support status: lunas, DP, hutang
- [ ] Daftar piutang (order belum lunas)
- [ ] Riwayat transaksi per tenant

### Mobile
- [ ] Form pembayaran saat order dibuat / diambil
- [ ] Daftar piutang customer
- [ ] Riwayat transaksi

---

## Fase 5 — Laporan (Minggu 15–16)

**Target**: Owner bisa pantau performa outlet.

### Backend
- [ ] API laporan pendapatan (harian, mingguan, bulanan)
- [ ] API laporan per layanan (order terbanyak, pendapatan per kategori)
- [ ] API ringkasan piutang
- [ ] Export PDF & CSV

### Mobile
- [ ] Dashboard Owner: ringkasan hari ini, grafik pendapatan
- [ ] Halaman laporan lengkap
- [ ] Tombol export

---

## Fase 6 — Polish & Launch (Minggu 17–20)

**Target**: Siap production, onboarding tenant pertama.

### Semua
- [ ] Notifikasi WA ke customer (via Evolution API + n8n) — opsional
- [ ] Onboarding flow untuk tenant baru
- [ ] Error handling & empty states
- [ ] Loading skeleton UI
- [ ] Unit test & integration test (backend)
- [ ] Widget test (Flutter)
- [ ] Rate limiting & keamanan API
- [ ] Query optimization & caching
- [ ] Setup CI/CD (GitHub Actions → VPS)
- [ ] Deploy production + SSL (acme.sh)
- [ ] Submit Flutter app ke Play Store

---

## Fase 7 — Post-Launch (Opsional)

- Notifikasi WA otomatis (aktif by default, bukan opsional lagi)
- Fitur multi-outlet per tenant (satu owner, banyak cabang)
- Paket/plan berlangganan (Starter, Pro, Business)
- Cetak struk / label tiket (Bluetooth printer)
- Loyalty points / poin reward customer (dicatat oleh vendor)
- Web dashboard owner (Next.js) sebagai alternatif mobile

---

## Summary Timeline

| Fase | Durasi | Output |
|------|--------|--------|
| 1 — Foundation | 3 minggu | Auth + multi-tenant scope |
| 2 — Master Data & Customer | 3 minggu | Data dasar & manajemen customer |
| 3 — Order & Tracking | 5 minggu | Fitur inti end-to-end |
| 4 — Transaksi & Pembayaran | 3 minggu | Pencatatan keuangan |
| 5 — Laporan | 2 minggu | Laporan & export |
| 6 — Polish & Launch | 4 minggu | Production-ready |
| **Total** | **~20 minggu** | |
