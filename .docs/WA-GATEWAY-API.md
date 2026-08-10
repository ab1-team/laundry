# WA Gateway API

Dokumentasi lengkap integrasi aplikasi ini dengan WA Gateway (n8n webhook-test)
untuk WhatsApp Business via Evolution API.

## Arsitektur

```
[Browser aplikasi]
    │  JS ajax (CSRF + Accept JSON)
    ▼
[Laravel routes] — bearer Basic disimpan di server (env), tidak pernah bocor
    │  Guzzle HTTP + Basic Auth header
    ▼
[n8n webhook-test] — https://agent.sidbm.net/webhook-test/*
    │  workflow internal
    ▼
[Evolution API] — bicara dengan WhatsApp
```

**Tidak ada** request langsung browser → gateway. Semua lewat Laravel server-side
agar credential Basic n8n (`enpii:its.enpii-118`) tidak bocor.

## Konfigurasi (`.env`)

```
WA_GATEWAY_BASE=https://agent.sidbm.net/webhook-test
WA_GATEWAY_API_KEY=enpii:its.enpii-118
```

`WA_GATEWAY_API_KEY` di-encode `base64` lalu dikirim sebagai
`Authorization: Basic <base64>`. Format key: `user:pass` (colon-separated).

## Autentikasi

Semua request Laravel → n8n memakai:
- `Authorization: Basic base64(WA_GATEWAY_API_KEY)`
- `Content-Type: application/json`
- `Accept: application/json`
- `User-Agent: Mozilla/5.0 ... Chrome/124` (Cloudflare WAF enpii block `GuzzleHttp/7`)

## Daftar Endpoint

### 1. Create Instance

**Trigger:** User klik tombol "Buat Instance" di menu SOP → Aktifasi Whatsapp.

**Laravel:**
- Route: `POST /pengaturan/whatsapp/save_device`
- Controller: `SopController::save_whatsapp_session`
- Middleware: `auth`

**Request Laravel → n8n:**
```http
POST {WA_GATEWAY_BASE}/create-instance
Authorization: Basic base64(enpii:its.enpii-118)
Content-Type: application/json

{"instance": "app-bumdesma-...", "lokasi": "lkd-1"}
```

**Response n8n → Laravel:**
```json
{
  "success": true,
  "instance": {
    "name": "app-bumdesma-...",
    "status": "connecting",
    "qr": "data:image/png;base64,iVBORw..."
  }
}
```

**Response Laravel → browser:**
```json
{
  "success": true,
  "instance": "app-bumdesma-...",
  "qr": "data:image/png;base64,iVBORw...",
  "pairingCode": null,
  "state": "connecting"
}
```

**Persist:** `Whatsapp::updateOrCreate(['lokasi' => $lokasi], ['nama', 'instance_name', 'status' => 'pending'])`

**Aturan nama instance:**
- Prefix wajib: `app-` (di-hardcode di `SopController::save_whatsapp_session`)
- Format: `app-{slug(nama_lembaga_sort)}-{kec->id}`
- Contoh: `app-bumdesma-satu-desa-mandiri-lkd-1`

**Fallback:** Kalau response `qr` null, Laravel coba restart + poll `/instance/connect/{name}` Evolution-style (legacy code, biasanya tidak jalan — webhook-test tidak expose path itu).

---

### 2. Get Instance State (polling)

**Trigger:** Frontend SOP polling setiap 2-3 detik setelah create / saat user buka modal scan QR.

**Laravel:**
- Route: `GET /pengaturan/whatsapp/instance_state`
- Controller: `WhatsappController::instanceState`
- Middleware: `auth`

**Request Laravel → n8n:**
```http
GET {WA_GATEWAY_BASE}/instance-state?instance=app-bumdesma-...
```

**Response n8n → Laravel:**
```json
{
  "success": true,
  "instance": {
    "name": "app-bumdesma-...",
    "status": "connecting|open|close",
    "qr": "data:image/png;base64,..." // optional, hanya saat status != open
  }
}
```

**Response Laravel → browser:**
```json
{"success": true, "state": "connecting", "qr": "data:image/png;base64,..."}
```

**DB side-effect:** Kalau `state === 'open'` → update `whatsapp.status = 'connected'`.

---

### 3. Delete Instance

**Trigger:** User klik "Hapus Whatsapp" di SOP.

**Laravel:**
- Route: `POST /pengaturan/whatsapp/delete_session`
- Controller: `SopController::delete_whatsapp_session`
- Middleware: `auth`

**Request Laravel → n8n:**
```http
DELETE {WA_GATEWAY_BASE}/delete-instance?instance=app-bumdesma-...
```

**Response n8n → Laravel:** (tidak diparse — Laravel langsung hapus row DB lokal)
```json
{"success": true}
```

**Response Laravel → browser:**
```json
{"success": true, "deleted": 1}
```

**DB side-effect:** `Whatsapp::where('lokasi', $lokasi)->delete()`

---

### 4. Send Single Message

**Trigger:**
- `dashboard/index.blade.php` — `msgInvoice` (setelah user bayar invoice, kirim reminder ke HP direksi)
- `transaksi/jurnal_angsuran/index.blade.php` — `sendMsg` (setelah posting angsuran, kirim ke ketua kelompok)

**Laravel:**
- Route: `POST /wa/send`
- Controller: `WhatsappController::sendMessage`
- Middleware: `auth`

**Request body (dari frontend):**
```json
{
  "number": "628xxx",
  "text": "...",
  "instance": "app-bumdesma-..."  // optional, fallback ke session->lokasi
}
```

**Validasi:** `number` & `text` required.

**Request Laravel → n8n:**
```http
POST {WA_GATEWAY_BASE}/send-message
Content-Type: application/json

{
  "instance": "app-bumdesma-...",
  "number": "628xxx",
  "text": "...",
  "delay": 2734   // random 1500-3500ms, anti-spam detection
}
```

**Response n8n → Laravel:**
```json
{"success": true}
```

**Response Laravel → browser:**
```json
{"success": true, "delay": 2734}
```

---

### 5. Send Bulk Messages

**Trigger:** `dashboard/index.blade.php` — `KirimPesan` (tombol "Kirim Pesan" di modal tagihan, multi-select nomor).

**Laravel:**
- Route: `POST /wa/send-bulk`
- Controller: `WhatsappController::sendMessages`
- Middleware: `auth`

**Request body (dari frontend):**
```json
{
  "instance": "app-bumdesma-...",
  "messages": [
    {"number": "628xxx", "text": "..."},
    {"number": "628yyy", "text": "..."}
  ]
}
```

**Validasi:** `messages` array required, min 1, tiap item harus ada `number` & `text`.

**Request Laravel → n8n:**
```http
POST {WA_GATEWAY_BASE}/send-messages
Content-Type: application/json

{
  "instance": "app-bumdesma-...",
  "messages": [
    {"number": "628xxx", "text": "..."},
    {"number": "628yyy", "text": "..."}
  ]
}
```

**Response n8n → Laravel:**
```json
{"success": true}
```
Generic — bulk tidak track per message.

**Response Laravel → browser:**
```json
{"success": true, "count": 2}
```

---

### 6. Get History Messages

**Trigger:** Frontend (planned) — audit trail pesan keluar per instance.

**Laravel:**
- Route: `GET /wa/history`
- Controller: `WhatsappController::historyMessage`
- Middleware: `auth`

**Request Laravel → n8n:**
```http
GET {WA_GATEWAY_BASE}/history-message?instance=app-bumdesma-...
```

**Response n8n → Laravel:**
```json
{
  "success": true,
  "data": [
    {
      "whatsapp_id": "1",
      "message": "test dari aplikasi",
      "status": "pending|sent|delivered",
      "id": 1,
      "createdAt": "2026-07-31T08:15:47.466Z",
      "updatedAt": "2026-07-31T08:15:47.466Z"
    }
  ]
}
```

**Response Laravel → browser:** raw body n8n diteruskan apa adanya.

---

## Struktur DB

### Tabel `whatsapp`
| kolom | tipe | keterangan |
|---|---|---|
| `id` | PK | auto |
| `lokasi` | string | FK ke kecamatan (string PK, bukan int) |
| `nama` | string | nama lembaga |
| `instance_name` | string | prefix `app-`, mis. `app-bumdesma-...-lkd-1` |
| `status` | enum string | `pending` / `connected` |
| `deletedAt` | datetime | soft delete (saat ini tidak dipakai aktif) |

### Tabel `kecamatan.whatsapp` (kolom JSON di tabel `kecamatan`)
```json
{"tagihan": "...template pesan...", "angsuran": "...template pesan..."}
```
Disimpan via `SopController::pesanWhatsapp` (route `PUT /pengaturan/pesan_whatsapp/{kec}`).

Template pesan pakai placeholder `{Nama Kelompok}`, `{Nama Desa}`, `{Angsuran Pokok}`, `{Angsuran Jasa}`, `{Tanggal Angsuran}`, `{User Login}`, `{Telpon}`. Substitution dilakukan server-side di `TransaksiController` & `DashboardController::tagihan`.

---

## Aturan Keamanan

1. **Bearer tidak pernah di browser.** `WA_GATEWAY_API_KEY` cuma di server. View tidak boleh render `api_key` / `apikey`.
2. **CSRF token** untuk semua POST dari frontend.
3. **Auth middleware** wajib di setiap route WA.
4. **Session `lokasi`** menentukan instance mana yang dipakai. Backend lookup `Whatsapp::where('lokasi', Session::get('lokasi'))`.

## Frontend Mapping

| Aksi UI | View | Endpoint |
|---|---|---|
| Buat Instance | `sop/partials/_whatsapp.blade.php` | `POST /pengaturan/whatsapp/save_device` → `/create-instance` |
| Scan QR / polling | `sop/index.blade.php` | `GET /pengaturan/whatsapp/instance_state` → `/instance-state` |
| Hapus Instance | `sop/index.blade.php` | `POST /pengaturan/whatsapp/delete_session` → `/delete-instance` |
| Kirim Tagihan (bulk) | `dashboard/index.blade.php` `KirimPesan` | `POST /wa/send-bulk` → `/send-messages` |
| Kirim Invoice reminder | `dashboard/index.blade.php` `msgInvoice` | `POST /wa/send` → `/send-message` |
| Kirim Angsuran | `transaksi/jurnal_angsuran/index.blade.php` `sendMsg` | `POST /wa/send` → `/send-message` |

## Troubleshooting

| Gejala | Penyebab | Fix |
|---|---|---|
| 403 "Authorization data is wrong!" | Bearer salah format / nilai | Pastikan `.env` `WA_GATEWAY_API_KEY=enpii:its.enpii-118` |
| 500 "No Respond to Webhook node found" | Workflow n8n belum ada Respond node di akhir alur | Tambah Respond node, set body, klik Execute |
| 404 "webhook not registered" | Path n8n berbeda dengan Laravel | Cek `WA_GATEWAY_BASE` + path di `WhatsappController` |
| QR image "No image" | `qr` null di response n8n | Cek alur n8n `create-instance` — pastikan ada step yang extract QR dari Evolution |
| Status stuck `connecting` | User belum scan QR di WA, atau callback n8n tidak update | Scan QR dari HP, atau tambah polling manual cek `instance-state` |
| `instance` key conflict di response | n8n return shape beda (`data.instance` vs `instance` flat) | Laravel sudah handle dua-duanya (fallback `??`) |

## File-file terkait

| File | Isi |
|---|---|
| `app/Http/Controllers/WhatsappController.php` | instanceState, sendMessage, sendMessages, historyMessage |
| `app/Http/Controllers/SopController.php` | save_whatsapp_session (create), delete_whatsapp_session |
| `routes/web.php` | routes WA di bawah `/pengaturan/whatsapp/*` & `/wa/*` |
| `app/Models/Whatsapp.php` | Eloquent model tabel `whatsapp` |
| `app/Models/Kecamatan.php` | relasi `wa_session` hasOne Whatsapp |
| `resources/views/sop/index.blade.php` | polling state UI |
| `resources/views/sop/partials/_whatsapp.blade.php` | form setup pesan + tombol Create/Scan/Delete |
| `resources/views/dashboard/index.blade.php` | KirimPesan (bulk) + msgInvoice (single) |
| `resources/views/transaksi/jurnal_angsuran/index.blade.php` | sendMsg setelah angsuran |
