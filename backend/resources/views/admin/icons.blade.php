@extends('admin.layout')

@section('title', 'Icon Manager')
@section('heading', 'Icon Manager')

@push('styles')
    <style>
        /* CSS scoped untuk Icon Manager — di-include di head layout via @stack('styles'). */
        .icon-form { display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap; }
        .icon-form .field { flex: 1; min-width: 200px; margin-bottom: 0; }
        .icon-form .field.file-field { flex: 0 0 auto; min-width: 260px; }
        .icon-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
            gap: 16px;
        }
        .icon-card {
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 12px;
            background: var(--surface);
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .icon-card.inactive { opacity: 0.5; }
        .icon-preview {
            aspect-ratio: 1;
            background: #f9fafb;
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }
        .icon-preview img { width: 100%; height: 100%; object-fit: contain; padding: 8px; }
        .icon-preview .placeholder { color: var(--muted); font-size: 12px; }
        .icon-name { font-weight: 600; font-size: 14px; word-break: break-word; }
        .icon-actions { display: flex; gap: 6px; flex-wrap: wrap; }
        .icon-actions form { margin: 0; }
        .icon-actions button { cursor: pointer; }
    </style>
@endpush

@section('content')

    {{-- ====== Form Tambah Icon ====== --}}
    <div class="card">
        <h3 style="margin: 0 0 16px; font-size: 16px;">Tambah icon baru</h3>
        <form method="POST" action="{{ route('admin.icons.store') }}" enctype="multipart/form-data" class="icon-form">
            @csrf
            <div class="field">
                <label for="name">Nama</label>
                <input id="name" name="name" type="text" placeholder="Contoh: Cuci Kering" value="{{ old('name') }}" required>
            </div>
            <div class="field file-field">
                <label for="icon">File icon (PNG/JPG/WebP, maks 1 MB)</label>
                <input id="icon" name="icon" type="file" accept="image/png,image/jpeg,image/webp" required>
            </div>
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Tambah</button>
            </div>
        </form>
        <p class="muted" style="margin-top: 12px;">
            Icon dipakai global oleh semua tenant — upload sekali, langsung muncul di picker form Kategori & Layanan mobile.
        </p>
    </div>

    {{-- ====== Daftar Icon ====== --}}
    <div class="card">
        <h3 style="margin: 0 0 16px; font-size: 16px;">Daftar icon</h3>

        @if ($icons->isEmpty())
            <div class="empty">Belum ada icon. Upload icon pertama di form atas.</div>
        @else
            <div class="icon-grid">
                @foreach ($icons as $icon)
                    <div class="icon-card {{ $icon->is_active ? '' : 'inactive' }}">
                        <div class="icon-preview">
                            @if ($icon->icon_path)
                                <img src="{{ asset('storage/' . $icon->icon_path) }}" alt="{{ $icon->name }}">
                            @else
                                <span class="placeholder">Belum ada file</span>
                            @endif
                        </div>
                        <div class="icon-name">{{ $icon->name }}</div>
                        <div>
                            @if ($icon->is_active)
                                <span class="badge badge-success">Aktif</span>
                            @else
                                <span class="badge badge-muted">Non-aktif</span>
                            @endif
                        </div>
                        <div class="icon-actions">
                            {{-- Toggle aktif/nonaktif via form inline (no JS) --}}
                            <form method="POST" action="{{ route('admin.icons.update', $icon) }}">
                                @csrf
                                @method('PATCH')
                                <input type="hidden" name="name" value="{{ $icon->name }}">
                                <input type="hidden" name="is_active" value="{{ $icon->is_active ? '0' : '1' }}">
                                <button type="submit" class="btn btn-outline btn-sm">
                                    {{ $icon->is_active ? 'Nonaktifkan' : 'Aktifkan' }}
                                </button>
                            </form>

                            {{-- Replace file: form upload terpisah --}}
                            <button type="button" class="btn btn-outline btn-sm" onclick="document.getElementById('replace-{{ $icon->id }}').click()">
                                Replace
                            </button>
                            <form id="replace-{{ $icon->id }}" method="POST" action="{{ route('admin.icons.update', $icon) }}" enctype="multipart/form-data" style="display: none;">
                                @csrf
                                @method('PATCH')
                                <input type="hidden" name="name" value="{{ $icon->name }}">
                                <input type="hidden" name="is_active" value="{{ $icon->is_active ? '1' : '0' }}">
                                <input type="file" name="icon" accept="image/png,image/jpeg,image/webp" onchange="this.form.submit()">
                            </form>

                            <form method="POST" action="{{ route('admin.icons.destroy', $icon) }}">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="btn btn-danger btn-sm"
                                        onclick="return confirm('Hapus icon &quot;{{ $icon->name }}&quot;? Kategori/layanan yang memakainya akan kehilangan icon.')">
                                    Hapus
                                </button>
                            </form>
                        </div>
                    </div>
                @endforeach
            </div>

            <div style="margin-top: 16px;">
                {{ $icons->links() }}
            </div>
        @endif
    </div>
@endsection