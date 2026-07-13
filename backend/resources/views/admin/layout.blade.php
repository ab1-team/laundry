<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    {{-- CSRF token untuk semua form POST/PATCH/DELETE di panel ini. --}}
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Admin') · LaundryAja</title>
    {{-- Styles tambahan per-halaman (mis. scoped CSS Icon Manager). --}}
    @stack('styles')
    <style>
        :root {
            --bg: #f5f7fa;
            --surface: #ffffff;
            --border: #e3e6eb;
            --text: #1a1f2e;
            --muted: #6b7280;
            --primary: #2c3a5e;
            --primary-hover: #1f2a47;
            --success: #10b981;
            --error: #ef4444;
            --warning: #f59e0b;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.5;
        }
        .layout { display: flex; min-height: 100vh; }
        .sidebar {
            width: 240px;
            background: var(--primary);
            color: #fff;
            padding: 24px 0;
            flex-shrink: 0;
        }
        .sidebar h1 {
            font-size: 18px;
            margin: 0 24px 32px;
            font-weight: 700;
            letter-spacing: -0.02em;
        }
        .sidebar nav a {
            display: block;
            padding: 12px 24px;
            color: rgba(255,255,255,0.85);
            text-decoration: none;
            font-size: 14px;
            border-left: 3px solid transparent;
        }
        .sidebar nav a:hover {
            background: rgba(255,255,255,0.08);
            color: #fff;
        }
        .sidebar nav a.active {
            background: rgba(255,255,255,0.12);
            border-left-color: #fff;
            color: #fff;
        }
        .main { flex: 1; padding: 32px; max-width: 1100px; }
        .topbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
        }
        .topbar h2 { margin: 0; font-size: 22px; font-weight: 700; }
        .topbar .user { font-size: 14px; color: var(--muted); }
        .topbar .user strong { color: var(--text); }
        .topbar form { display: inline; margin-left: 12px; }
        .btn-link {
            background: none;
            border: none;
            color: var(--primary);
            cursor: pointer;
            font-size: 14px;
            padding: 0;
            text-decoration: underline;
        }
        .card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 24px;
            margin-bottom: 16px;
        }
        .flash {
            padding: 12px 16px;
            border-radius: 6px;
            margin-bottom: 16px;
            font-size: 14px;
        }
        .flash-success {
            background: #ecfdf5;
            border: 1px solid #a7f3d0;
            color: #065f46;
        }
        .flash-error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #991b1b;
        }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th, td { text-align: left; padding: 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
        th { background: #f9fafb; font-weight: 600; color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; }
        tr.active-row { background: #f0fdf4; }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge-success { background: #d1fae5; color: #065f46; }
        .badge-warning { background: #fef3c7; color: #92400e; }
        .badge-muted { background: #f3f4f6; color: #4b5563; }
        .btn {
            display: inline-block;
            padding: 8px 14px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 600;
            border: 1px solid transparent;
            cursor: pointer;
            text-decoration: none;
            transition: background 0.15s;
        }
        .btn-primary { background: var(--primary); color: #fff; }
        .btn-primary:hover { background: var(--primary-hover); }
        .btn-success { background: var(--success); color: #fff; }
        .btn-success:hover { background: #0ea271; }
        .btn-outline { background: transparent; border-color: var(--border); color: var(--text); }
        .btn-outline:hover { background: #f9fafb; }
        .btn-danger { background: transparent; color: var(--error); border-color: #fecaca; }
        .btn-danger:hover { background: #fef2f2; }
        .btn-sm { padding: 4px 10px; font-size: 12px; }
        label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 4px; color: var(--text); }
        input[type="text"], input[type="email"], input[type="password"], input[type="number"], textarea {
            width: 100%;
            padding: 8px 10px;
            border: 1px solid var(--border);
            border-radius: 6px;
            font-size: 14px;
            font-family: inherit;
        }
        input:focus, textarea:focus { outline: 2px solid var(--primary); outline-offset: -1px; }
        .field { margin-bottom: 12px; }
        .field-row { display: flex; gap: 12px; }
        .field-row > .field { flex: 1; }
        .form-actions { margin-top: 16px; display: flex; gap: 8px; }
        .checkbox-row { display: flex; align-items: center; gap: 8px; }
        .checkbox-row input[type="checkbox"] { width: auto; }
        code { background: #f3f4f6; padding: 1px 6px; border-radius: 4px; font-size: 12px; }
        .muted { color: var(--muted); font-size: 13px; }
        .empty { text-align: center; padding: 40px 20px; color: var(--muted); }
    </style>
</head>
<body>
    <div class="layout">
        <aside class="sidebar">
            <h1>LaundryAja Admin</h1>
            <nav>
                <a href="{{ route('admin.releases.index') }}" class="{{ request()->routeIs('admin.releases.*') ? 'active' : '' }}">
                    Release Manager
                </a>
                <a href="{{ route('admin.icons.index') }}" class="{{ request()->routeIs('admin.icons.*') ? 'active' : '' }}">
                    Icon Manager
                </a>
            </nav>
        </aside>
        <main class="main">
            <div class="topbar">
                <h2>@yield('heading', 'Dashboard')</h2>
                <div class="user">
                    Login sebagai <strong>{{ auth()->user()->name }}</strong>
                    <form method="POST" action="{{ route('admin.logout') }}">
                        @csrf
                        <button type="submit" class="btn-link">Logout</button>
                    </form>
                </div>
            </div>

            @if (session('status'))
                <div class="flash flash-success">{{ session('status') }}</div>
            @endif
            @if ($errors->any() && ! $errors->has('email'))
                <div class="flash flash-error">
                    <ul style="margin: 0; padding-left: 20px;">
                        @foreach ($errors->all() as $error)
                            <li>{{ $error }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif

            @yield('content')
        </main>
    </div>
</body>
</html>