@extends('admin.layout')

@section('title', 'User Manager')
@section('heading', 'User Manager')

@push('styles')
    <style>
        /* CSS scoped untuk User Manager. Semua class lain reuse dari
           layout (card, field-row, btn, badge, nav[role=navigation]). */
        .filter-form .field { margin-bottom: 0; }
        .filter-form { display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap; }
        .filter-form .field { flex: 1; min-width: 160px; }
        .filter-form .field.search { flex: 2; min-width: 220px; }
        .filter-form .actions { display: flex; gap: 8px; }

        .role-super { background: #ede9fe; color: #5b21b6; }
        .role-owner { background: #dbeafe; color: #1e40af; }
        .role-operator { background: #f3f4f6; color: #374151; }

        /* Stat tiles — ringkasan di atas halaman supaya admin langsung
           lihat kondisi user base tanpa scroll ke tabel. */
        .stats-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
            gap: 12px;
            margin-bottom: 16px;
        }
        .stat-tile {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 14px 16px;
        }
        .stat-tile .label { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; }
        .stat-tile .value { font-size: 24px; font-weight: 700; line-height: 1.1; margin-top: 4px; color: var(--text); }
        .stat-tile .sub { font-size: 12px; color: var(--muted); margin-top: 2px; }
        .stat-tile.primary { border-left: 3px solid var(--primary); }
        .stat-tile.success { border-left: 3px solid var(--success); }
        .stat-tile.muted { border-left: 3px solid var(--border); }
        .stat-tile.warn   { border-left: 3px solid var(--warning); }

        /* Page intro — paragraf pendek di bawah heading. */
        .page-intro { color: var(--muted); font-size: 14px; margin: 0 0 20px; max-width: 720px; }

        /* Section heading + supporting hint di header card. */
        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            gap: 12px;
            margin-bottom: 16px;
            flex-wrap: wrap;
        }
        .card-header h3 { margin: 0; font-size: 16px; }
        .card-header .hint { color: var(--muted); font-size: 12px; }

        /* Empty state — lebih dari sekadar teks; ada CTA supaya admin
           tidak bingung saat tabel kosong (mis. tenant baru). */
        .empty-state {
            text-align: center;
            padding: 48px 20px;
            color: var(--muted);
            border: 1px dashed var(--border);
            border-radius: 8px;
            background: #fafbfc;
        }
        .empty-state .emoji { font-size: 36px; margin-bottom: 8px; }
        .empty-state h4 { margin: 0 0 6px; font-size: 15px; color: var(--text); font-weight: 600; }
        .empty-state p { margin: 0 0 16px; font-size: 13px; }

        /* Helper callout di form create — penjelasan kenapa tenant_id
           wajib/terkunci tergantung role. */
        .helper-callout {
            display: flex;
            gap: 10px;
            align-items: flex-start;
            padding: 10px 12px;
            background: #eff6ff;
            border: 1px solid #bfdbfe;
            border-radius: 6px;
            font-size: 13px;
            color: #1e40af;
            margin: 12px 0 0;
        }
        .helper-callout .icon { flex-shrink: 0; font-size: 16px; line-height: 1.4; }
        .helper-callout strong { color: #1e3a8a; }

        /* Baris yang sedang diedit — kasih background kuning lembut + auto-scroll
           supaya admin langsung lihat form edit yang terbuka. */
        tr.editing-row { background: #fffbeb; }
        tr.editing-row > td { border-bottom-color: #fde68a; }

        .user-actions {
            display: flex;
            gap: 6px;
            flex-wrap: wrap;
            align-items: flex-start;
        }
        .user-actions form { margin: 0; display: inline; }
        .user-actions details { width: 100%; }
        .user-actions details > summary {
            cursor: pointer;
            font-size: 12px;
            color: var(--primary);
            list-style: none;
            padding: 4px 0;
            font-weight: 600;
        }
        .user-actions details > summary::-webkit-details-marker { display: none; }
        .user-actions details > summary::before {
            content: '▸ ';
            display: inline-block;
            transition: transform 0.15s;
        }
        .user-actions details[open] > summary::before { content: '▾ '; }
        .user-actions .inline-form {
            margin-top: 8px;
            padding: 12px;
            background: #f9fafb;
            border: 1px solid var(--border);
            border-radius: 6px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        .user-actions .inline-form .field-row { gap: 8px; }
        .user-actions .inline-form .field { margin-bottom: 0; }
        .user-actions .inline-form input,
        .user-actions .inline-form select { font-size: 13px; padding: 6px 8px; }

        /* Kolom aksi biar tidak terlalu lebar — sembunyikan beberapa kolom
           di layar sempit. Tabel admin sudah punya tabel sederhana tanpa
           responsive table, tapi aksi tetap wrap. */
        td.actions-cell { min-width: 200px; }
    </style>
    <script>
        // Disable field tenant_id saat role = super_admin di form create
        // dan di setiap form edit. Logic ada di server juga (controller
        // mengosongkan tenant_id untuk super_admin), tapi ini supaya UI
        // tidak misleading.
        function toggleTenantRequired(roleSelect, tenantSelect) {
            if (!roleSelect || !tenantSelect) return;
            const isSuper = roleSelect.value === 'super_admin';
            tenantSelect.disabled = isSuper;
            if (isSuper) {
                tenantSelect.value = '';
            }
        }
        document.addEventListener('DOMContentLoaded', () => {
            document.querySelectorAll('select[data-role-select]').forEach(roleSel => {
                const form = roleSel.closest('form');
                const tenantSel = form.querySelector('select[data-tenant-select]');
                toggleTenantRequired(roleSel, tenantSel);
                roleSel.addEventListener('change', () => toggleTenantRequired(roleSel, tenantSel));
            });

            // Auto-scroll ke baris edit yang sedang dibuka, supaya admin
            // tidak perlu scroll manual cari form edit setelah klik "Edit".
            const editing = document.querySelector('tr.editing-row');
            if (editing) {
                editing.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        });
    </script>
@endpush

@section('content')

    <p class="page-intro">
        Kelola akun <strong>super admin</strong>, <strong>owner</strong>, dan <strong>operator</strong> di semua tenant. Onboarding user baru, ubah role/nonaktifkan akun, atau reset password lewat sini. Setelah membuat user, berikan password awal ke mereka lewat komunikasi terpisah — sistem tidak mengirim email.
    </p>

    {{-- ====== Stats ringkasan ====== --}}
    <div class="stats-row">
        <div class="stat-tile primary">
            <div class="label">Total user</div>
            <div class="value">{{ $stats['total'] }}</div>
            <div class="sub">{{ $stats['active'] }} aktif · {{ $stats['total'] - $stats['active'] }} nonaktif</div>
        </div>
        <div class="stat-tile muted">
            <div class="label">Super admin</div>
            <div class="value">{{ $stats['super_admin'] }}</div>
            <div class="sub">Akses global ke panel</div>
        </div>
        <div class="stat-tile muted">
            <div class="label">Owner</div>
            <div class="value">{{ $stats['owners'] }}</div>
            <div class="sub">Pemilik / admin tenant</div>
        </div>
        <div class="stat-tile muted">
            <div class="label">Operator</div>
            <div class="value">{{ $stats['operators'] }}</div>
            <div class="sub">Staf operasional tenant</div>
        </div>
        <div class="stat-tile success">
            <div class="label">Tenant aktif</div>
            <div class="value">{{ $stats['tenants'] }}</div>
            <div class="sub">Tersedia untuk assign owner/operator</div>
        </div>
    </div>

    {{-- ====== Filter ====== --}}
    <div class="card">
        <div class="card-header">
            <h3>Filter</h3>
            <span class="hint">Saring tabel di bawah. Filter disimpan di URL jadi bisa dishare.</span>
        </div>
        <form method="GET" action="{{ route('admin.users.index') }}" class="filter-form">
            <div class="field search">
                <label for="q">Cari nama / email</label>
                <input id="q" name="q" type="text" placeholder="Contoh: budi@laundry.com" value="{{ $filters['q'] }}">
            </div>
            <div class="field">
                <label for="tenant_id">Tenant</label>
                <select id="tenant_id" name="tenant_id">
                    <option value="">— Semua tenant —</option>
                    @foreach ($tenants as $t)
                        <option value="{{ $t->id }}" {{ (string) $filters['tenant_id'] === (string) $t->id ? 'selected' : '' }}>
                            {{ $t->name }}
                        </option>
                    @endforeach
                </select>
            </div>
            <div class="field">
                <label for="role">Role</label>
                <select id="role" name="role">
                    <option value="">— Semua role —</option>
                    @foreach (['super_admin', 'owner', 'operator'] as $r)
                        <option value="{{ $r }}" {{ $filters['role'] === $r ? 'selected' : '' }}>{{ $r }}</option>
                    @endforeach
                </select>
            </div>
            <div class="field">
                <label for="is_active">Status</label>
                <select id="is_active" name="is_active">
                    @php $ia = (string) $filters['is_active']; @endphp
                    <option value="" {{ $ia === '' ? 'selected' : '' }}>Semua</option>
                    <option value="1" {{ $ia === '1' ? 'selected' : '' }}>Aktif</option>
                    <option value="0" {{ $ia === '0' ? 'selected' : '' }}>Nonaktif</option>
                </select>
            </div>
            <div class="actions">
                <button type="submit" class="btn btn-primary">Terapkan</button>
                <a href="{{ route('admin.users.index') }}" class="btn btn-outline">Reset</a>
            </div>
        </form>
    </div>

    {{-- ====== Form Tambah User ====== --}}
    <div class="card">
        <div class="card-header">
            <h3>Tambah user baru</h3>
            <span class="hint">Buat akun untuk owner/operator tenant baru, atau tambah super admin lain.</span>
        </div>
        <form method="POST" action="{{ route('admin.users.store') }}">
            @csrf
            <div class="field-row">
                <div class="field">
                    <label for="name">Nama</label>
                    <input id="name" name="name" type="text" value="{{ old('name') }}" required>
                </div>
                <div class="field">
                    <label for="email">Email</label>
                    <input id="email" name="email" type="email" value="{{ old('email') }}" required>
                </div>
            </div>
            <div class="field-row">
                <div class="field">
                    <label for="password">Password</label>
                    <input id="password" name="password" type="password" minlength="8" required>
                </div>
                <div class="field">
                    <label for="password_confirmation">Konfirmasi password</label>
                    <input id="password_confirmation" name="password_confirmation" type="password" minlength="8" required>
                </div>
            </div>
            <div class="field-row">
                <div class="field">
                    <label for="role_create">Role</label>
                    <select id="role_create" name="role" data-role-select required>
                        @php $oldRole = old('role', 'operator'); @endphp
                        <option value="super_admin" {{ $oldRole === 'super_admin' ? 'selected' : '' }}>super_admin</option>
                        <option value="owner" {{ $oldRole === 'owner' ? 'selected' : '' }}>owner</option>
                        <option value="operator" {{ $oldRole === 'operator' ? 'selected' : '' }}>operator</option>
                    </select>
                </div>
                <div class="field">
                    <label for="tenant_id_create">Tenant</label>
                    <select id="tenant_id_create" name="tenant_id" data-tenant-select>
                        <option value="">— Pilih tenant —</option>
                        @foreach ($tenants as $t)
                            <option value="{{ $t->id }}" {{ (string) old('tenant_id') === (string) $t->id ? 'selected' : '' }}>{{ $t->name }}</option>
                        @endforeach
                    </select>
                </div>
            </div>
            <div class="helper-callout">
                <span class="icon">ℹ️</span>
                <div>
                    <strong>Hubungan role ↔ tenant:</strong>
                    <strong>super_admin</strong> tidak terikat tenant (akses global).
                    <strong>owner</strong> dan <strong>operator</strong> wajib terikat satu tenant.
                    Pilih role dulu — field tenant akan otomatis nonaktif saat role = super_admin.
                </div>
            </div>
            <div class="field checkbox-row">
                <input id="is_active_create" name="is_active" type="checkbox" value="1" {{ old('is_active', true) ? 'checked' : '' }}>
                <label for="is_active_create" style="margin: 0;">Aktif (user bisa login)</label>
            </div>
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Tambah user</button>
            </div>
        </form>
    </div>

    {{-- ====== Tabel User ====== --}}
    <div class="card">
        <div class="card-header">
            <h3>Daftar user</h3>
            @if ($users->total() > 0)
                <span class="hint">Menampilkan {{ $users->count() }} dari {{ $users->total() }} user</span>
            @endif
        </div>

        @if ($users->isEmpty())
            <div class="empty-state">
                <div class="emoji">👥</div>
                @if (collect($filters)->filter()->isNotEmpty())
                    <h4>Tidak ada user yang cocok dengan filter</h4>
                    <p>Coba perluas pencarian — misalnya reset filter, atau ganti role/tenant.</p>
                    <a href="{{ route('admin.users.index') }}" class="btn btn-outline btn-sm">Reset filter</a>
                @else
                    <h4>Belum ada user di sistem</h4>
                    <p>Mulai dengan tambah user pertama lewat form di atas. Owner dan operator wajib terikat satu tenant.</p>
                @endif
            </div>
        @else
            <table>
                <thead>
                    <tr>
                        <th>Nama / Email</th>
                        <th>Tenant</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Login terakhir</th>
                        <th>Dibuat</th>
                        <th style="text-align: right;">Aksi</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($users as $u)
                        @php $isSelf = auth()->user()->is($u); @endphp
                        <tr class="{{ $editId === $u->id ? 'editing-row' : '' }} {{ $u->is_active ? '' : 'inactive-row' }}">
                            <td>
                                <strong>{{ $u->name }}</strong>
                                @if ($isSelf) <span class="badge badge-success">Anda</span> @endif
                                <div class="muted">{{ $u->email }}</div>
                            </td>
                            <td>
                                @if ($u->tenant)
                                    <span class="badge badge-muted">{{ $u->tenant->name }}</span>
                                @else
                                    <span class="muted">—</span>
                                @endif
                            </td>
                            <td>
                                <span class="badge role-{{ $u->role }}">{{ $u->role }}</span>
                            </td>
                            <td>
                                @if ($u->is_active)
                                    <span class="badge badge-success">Aktif</span>
                                @else
                                    <span class="badge badge-warning">Nonaktif</span>
                                @endif
                            </td>
                            <td>
                                @if ($u->last_login_at)
                                    <span title="{{ $u->last_login_at }}">{{ $u->last_login_at->diffForHumans() }}</span>
                                @else
                                    <span class="muted">Belum pernah</span>
                                @endif
                            </td>
                            <td>
                                <span class="muted">{{ $u->created_at->diffForHumans() }}</span>
                            </td>
                            <td class="actions-cell">
                                <div class="user-actions">
                                    {{-- Edit profil (inline). Disable untuk diri sendiri
                                         supaya UI tidak menggoda admin demote diri. --}}
                                    @unless ($isSelf)
                                        <details {{ $editId === $u->id ? 'open' : '' }}>
                                            <summary>Edit</summary>
                                            <form method="POST" action="{{ route('admin.users.update', $u) }}" class="inline-form">
                                                @csrf
                                                @method('PATCH')
                                                <input type="hidden" name="tenant_id" value="">
                                                <div class="field-row">
                                                    <div class="field">
                                                        <label>Nama</label>
                                                        <input name="name" type="text" value="{{ old('name', $u->name) }}" required>
                                                    </div>
                                                    <div class="field">
                                                        <label>Email</label>
                                                        <input name="email" type="email" value="{{ old('email', $u->email) }}" required>
                                                    </div>
                                                </div>
                                                <div class="field-row">
                                                    <div class="field">
                                                        <label>Role</label>
                                                        <select name="role" data-role-select required>
                                                            @foreach (['super_admin', 'owner', 'operator'] as $r)
                                                                <option value="{{ $r }}" {{ $u->role === $r ? 'selected' : '' }}>{{ $r }}</option>
                                                            @endforeach
                                                        </select>
                                                    </div>
                                                    <div class="field">
                                                        <label>Tenant</label>
                                                        <select name="tenant_id" data-tenant-select>
                                                            <option value="">—</option>
                                                            @foreach ($tenants as $t)
                                                                <option value="{{ $t->id }}" {{ (string) $u->tenant_id === (string) $t->id ? 'selected' : '' }}>{{ $t->name }}</option>
                                                            @endforeach
                                                        </select>
                                                    </div>
                                                </div>
                                                <div class="field checkbox-row">
                                                    <input type="hidden" name="is_active" value="0">
                                                    <input name="is_active" type="checkbox" value="1" {{ $u->is_active ? 'checked' : '' }}>
                                                    <label style="margin: 0;">Aktif</label>
                                                </div>
                                                <div style="display: flex; gap: 6px;">
                                                    <button type="submit" class="btn btn-primary btn-sm">Simpan</button>
                                                    <a href="{{ route('admin.users.index', array_merge(request()->only(['tenant_id','role','q','is_active']), ['edit' => null])) }}" class="btn btn-outline btn-sm">Batal</a>
                                                </div>
                                            </form>
                                        </details>
                                    @endunless

                                    {{-- Reset password (inline). Tidak tersedia untuk diri
                                         sendiri (admin harus pakai flow ganti password sendiri). --}}
                                    @unless ($isSelf)
                                        <details>
                                            <summary>Reset password</summary>
                                            <form method="POST" action="{{ route('admin.users.password', $u) }}" class="inline-form">
                                                @csrf
                                                @method('PATCH')
                                                <div class="field">
                                                    <label>Password baru (min 8)</label>
                                                    <input name="password" type="password" minlength="8" required>
                                                </div>
                                                <div class="field">
                                                    <label>Konfirmasi</label>
                                                    <input name="password_confirmation" type="password" minlength="8" required>
                                                </div>
                                                <div style="display: flex; gap: 6px;">
                                                    <button type="submit" class="btn btn-primary btn-sm">Reset</button>
                                                </div>
                                            </form>
                                        </details>
                                    @endunless

                                    {{-- Hapus. Server-side tolak untuk diri sendiri. --}}
                                    @unless ($isSelf)
                                        <form method="POST" action="{{ route('admin.users.destroy', $u) }}" onsubmit="return confirm('Hapus user {{ $u->email }}? Tindakan ini tidak bisa dibatalkan.');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="btn btn-danger btn-sm">Hapus</button>
                                        </form>
                                    @endunless
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>

            <div style="margin-top: 16px;">
                {{ $users->links() }}
            </div>
        @endif
    </div>

@endsection