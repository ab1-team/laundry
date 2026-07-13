@extends('admin.layout')

@section('title', 'Icon Manager')
@section('heading', 'Icon Manager')

@push('styles')
    <style>
        /* CSS scoped untuk Icon Manager — di-include di head layout via @stack('styles'). */
        .icon-form { display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap; }
        .icon-form .field { flex: 1; min-width: 200px; margin-bottom: 0; }
        .icon-form .field.file-field { flex: 0 0 auto; min-width: 280px; }
        .icon-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
            gap: 12px;
        }
        .icon-card {
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 12px;
            background: var(--surface);
            display: flex;
            flex-direction: column;
            gap: 8px;
            transition: border-color 0.15s, box-shadow 0.15s;
        }
        .icon-card:hover { border-color: var(--primary); box-shadow: 0 1px 4px rgba(44,58,94,0.08); }
        .icon-card.inactive { background: #f9fafb; border-style: dashed; }
        .icon-card.inactive .icon-preview { filter: grayscale(0.8); }
        .icon-preview {
            aspect-ratio: 1;
            background: #f9fafb;
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }
        .icon-card:not(.inactive) .icon-preview { background: linear-gradient(135deg, #f9fafb 0%, #f3f4f6 100%); }
        .icon-preview img { width: 100%; height: 100%; object-fit: contain; padding: 10px; }
        .icon-preview .placeholder { color: var(--muted); font-size: 12px; }
        .icon-name { font-weight: 600; font-size: 13px; word-break: break-word; line-height: 1.3; }
        .icon-actions { display: flex; gap: 4px; flex-wrap: wrap; margin-top: auto; }
        .icon-actions form { margin: 0; }
        .icon-actions button { cursor: pointer; flex: 1; min-width: 60px; }
    </style>
    <script>
        // Update label nama file ketika user pilih file.
        function updateFileName(inputId, labelId) {
            const input = document.getElementById(inputId);
            const label = document.getElementById(labelId);
            if (input && label) {
                input.addEventListener('change', () => {
                    label.textContent = input.files[0]?.name || 'Belum ada file dipilih';
                });
            }
        }
        document.addEventListener('DOMContentLoaded', () => {
            updateFileName('icon', 'icon-file-name');
            // Untuk setiap Replace form, attach listener
            document.querySelectorAll('input[type="file"][data-replace]').forEach(input => {
                const label = document.getElementById('replace-name-' + input.dataset.replace);
                input.addEventListener('change', () => {
                    if (input.files[0]) { input.form.submit(); }
                });
                // Trigger dari tombol Replace
                const trigger = document.querySelector('[data-replace-trigger="' + input.dataset.replace + '"]');
                if (trigger) {
                    trigger.addEventListener('click', () => input.click());
                }
            });
        });
    </script>
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
                <label>File icon (PNG/JPG/WebP, maks 1 MB)</label>
                <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    <div class="file-input-wrap">
                        <span class="file-input-label">📁 Pilih File</span>
                        <input id="icon" name="icon" type="file" accept="image/png,image/jpeg,image/webp" required>
                    </div>
                    <span id="icon-file-name" class="file-input-name">Belum ada file dipilih</span>
                </div>
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
                                <button type="submit" class="btn btn-outline btn-sm" title="{{ $icon->is_active ? 'Nonaktifkan' : 'Aktifkan' }}">
                                    {{ $icon->is_active ? 'Nonaktifkan' : 'Aktifkan' }}
                                </button>
                            </form>

                            {{-- Replace file: form upload terpisah (hidden file input, triggered by button) --}}
                            <form method="POST" action="{{ route('admin.icons.update', $icon) }}" enctype="multipart/form-data" style="display:none;">
                                @csrf
                                @method('PATCH')
                                <input type="hidden" name="name" value="{{ $icon->name }}">
                                <input type="hidden" name="is_active" value="{{ $icon->is_active ? '1' : '0' }}">
                                <input type="file" name="icon" accept="image/png,image/jpeg,image/webp" data-replace="{{ $icon->id }}">
                            </form>
                            <button type="button" class="btn btn-outline btn-sm" data-replace-trigger="{{ $icon->id }}" title="Ganti file icon">
                                Replace
                            </button>

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