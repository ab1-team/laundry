@extends('admin.layout')

@section('title', 'Release Manager')
@section('heading', 'Release Manager')

@section('content')
    {{-- ====== Form Create Rilis Baru ====== --}}
    <div class="card">
        <h3 style="margin: 0 0 16px; font-size: 16px;">Publikasikan rilis baru</h3>
        <form method="POST" action="{{ route('admin.releases.store') }}">
            @csrf
            <div class="field-row">
                <div class="field">
                    <label for="version">Version (versionName)</label>
                    <input id="version" name="version" type="text" placeholder="1.2.0" value="{{ old('version') }}" required>
                </div>
                <div class="field">
                    <label for="version_code">Version Code</label>
                    <input id="version_code" name="version_code" type="number" min="1" placeholder="12" value="{{ old('version_code') }}" required>
                </div>
            </div>
            <div class="field">
                <label for="min_version">Min Version (kosongkan jika tidak ada paksa update)</label>
                <input id="min_version" name="min_version" type="text" placeholder="1.1.0" value="{{ old('min_version') }}">
            </div>
            <div class="field">
                <label for="changelog">Changelog</label>
                <textarea id="changelog" name="changelog" rows="3" placeholder="Apa yang berubah di rilis ini?">{{ old('changelog') }}</textarea>
            </div>
            <div class="field checkbox-row">
                <input id="force_update" name="force_update" type="checkbox" value="1" {{ old('force_update') ? 'checked' : '' }}>
                <label for="force_update" style="margin: 0;">Force update (wajib, user tidak bisa skip)</label>
            </div>
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Buat rilis</button>
            </div>
            <p class="muted" style="margin-top: 12px;">
                Setelah dibuat, upload APK di tabel di bawah lalu klik <strong>Aktivasi</strong> untuk publish ke user.
            </p>
        </form>
    </div>

    {{-- ====== Daftar Rilis ====== --}}
    <div class="card">
        <h3 style="margin: 0 0 16px; font-size: 16px;">Daftar rilis</h3>

        @if ($releases->isEmpty())
            <div class="empty">Belum ada rilis. Buat rilis pertama di form atas.</div>
        @else
            <table>
                <thead>
                    <tr>
                        <th>Versi</th>
                        <th>Status</th>
                        <th>APK</th>
                        <th>Min Ver</th>
                        <th>Force</th>
                        <th>Changelog</th>
                        <th>Dipublikasikan</th>
                        <th style="text-align: right;">Aksi</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($releases as $r)
                        <tr class="{{ $r->is_active ? 'active-row' : '' }}">
                            <td>
                                <strong>{{ $r->version }}</strong>
                                <span class="muted">+{{ $r->version_code }}</span>
                            </td>
                            <td>
                                @if ($r->is_active)
                                    <span class="badge badge-success">AKTIF</span>
                                @elseif ($r->apk_path)
                                    <span class="badge badge-warning">Siap Publish</span>
                                @else
                                    <span class="badge badge-muted">Draft</span>
                                @endif
                            </td>
                            <td>
                                @if ($r->apk_path)
                                    <code>{{ $r->apk_path }}</code><br>
                                    <span class="muted">{{ number_format(($r->apk_size ?? 0) / 1024 / 1024, 2) }} MB</span>
                                @else
                                    <span class="muted">Belum upload</span>
                                @endif
                            </td>
                            <td>{{ $r->min_version ?: '—' }}</td>
                            <td>
                                @if ($r->force_update)
                                    <span class="badge badge-warning">Ya</span>
                                @else
                                    <span class="muted">Tidak</span>
                                @endif
                            </td>
                            <td style="max-width: 240px;">
                                <span class="muted">{{ $r->changelog ? \Illuminate\Support\Str::limit($r->changelog, 80) : '—' }}</span>
                            </td>
                            <td>
                                <span class="muted">
                                    {{ optional($r->published_at)->format('d M Y H:i') ?: '—' }}
                                </span>
                            </td>
                            <td style="text-align: right; white-space: nowrap;">
                                @if (! $r->is_active && $r->apk_path)
                                    <form method="POST" action="{{ route('admin.releases.activate', $r) }}" style="display: inline;">
                                        @csrf
                                        @method('PATCH')
                                        <button type="submit" class="btn btn-success btn-sm"
                                                onclick="return confirm('Aktifkan versi {{ $r->version }}? User akan dapat update pada buka app berikutnya.')">
                                            Aktivasi
                                        </button>
                                    </form>
                                @endif

                                <button type="button" class="btn btn-outline btn-sm" onclick="document.getElementById('upload-input-{{ $r->id }}').click()">
                                    {{ $r->apk_path ? 'Replace' : 'Upload' }} APK
                                </button>

                                <form id="upload-form-{{ $r->id }}" method="POST" action="{{ route('admin.releases.upload', $r) }}" enctype="multipart/form-data" style="display: none;">
                                    @csrf
                                    <input id="upload-input-{{ $r->id }}" type="file" name="apk" accept=".apk,application/vnd.android.package-archive"
                                           onchange="this.form.submit()">
                                </form>

                                <form method="POST" action="{{ route('admin.releases.destroy', $r) }}" style="display: inline;">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-danger btn-sm"
                                            onclick="return confirm('Hapus rilis {{ $r->version }}? APK juga ikut terhapus.')">
                                        Hapus
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>

            <div style="margin-top: 16px;">
                {{ $releases->links() }}
            </div>
        @endif
    </div>
@endsection