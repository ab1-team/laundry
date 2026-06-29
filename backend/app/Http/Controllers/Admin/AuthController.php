<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;

/**
 * Session-based login untuk admin panel.
 * Guard 'web' — beda dari guard API yang dipakai Sanctum untuk mobile.
 *
 * Kenapa pakai guard 'web' dan bukan Sanctum?
 *   - Sanctum = token stateless untuk API. Tidak ada konsep logout
 *     yang invalidate token.
 *   - Guard 'web' = session cookie + CSRF. Cocok untuk halaman HTML
 *     yang dibuka dari browser dengan state persisten (admin login
 *     sekali, sesi tahan sampai logout).
 */
class AuthController extends Controller
{
    public function showLogin()
    {
        return view('admin.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::attempt($credentials, true)) {
            // Throttle di-handle oleh Laravel's built-in throttle middleware,
            // tapi untuk sederhana kita pakai error message biasa dulu.
            throw ValidationException::withMessages([
                'email' => 'Email atau password salah.',
            ]);
        }

        $user = Auth::user();

        // Double-check role: super_admin only. Kalau bukan, langsung
        // logout lagi — supaya akun owner/operator tidak sengaja bisa
        // akses admin panel walaupun password-nya valid.
        if (! $user->isSuperAdmin()) {
            Auth::logout();
            throw ValidationException::withMessages([
                'email' => 'Akun ini tidak punya akses admin.',
            ]);
        }

        // Regenerate session ID setelah login berhasil — mitigasi session
        // fixation attack.
        $request->session()->regenerate();
        $user->update(['last_login_at' => now()]);

        return redirect()->intended(route('admin.home'));
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}