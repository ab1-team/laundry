<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\Response;

/**
 * Admin web controller untuk manage semua User — super_admin, owner, operator.
 *
 * Pattern sama dengan IconController / ReleaseController: query model
 * langsung (TIDAK via HTTP API), redirect-with-flash, view Blade.
 *
 * Guardrails yang diterapkan:
 *   - super_admin harus punya tenant_id NULL (admin global, bukan milik tenant).
 *   - owner/operator WAJIB terikat satu tenant (cascade on delete di FK).
 *   - Admin tidak boleh lock-out dirinya sendiri: tidak boleh demote role
 *     sendiri dari super_admin, menonaktifkan diri sendiri, atau menghapus
 *     akun sendiri dari panel. Dicegat di server (403) supaya tidak bisa
 *     di-bypass lewat inspect element / curl manual.
 */
class UserController extends Controller
{
    /**
     * Daftar user dengan filter (tenant, role, search, status).
     * Filter pakai GET query string supaya URL bisa di-bookmark & dishare.
     */
    public function index(Request $request)
    {
        $tenants = Tenant::query()->orderBy('name')->get(['id', 'name']);

        $users = User::query()
            ->with('tenant:id,name')
            ->when($request->filled('tenant_id'), fn ($q) => $q->where('tenant_id', $request->integer('tenant_id')))
            ->when($request->filled('role'), fn ($q) => $q->where('role', $request->string('role')))
            ->when($request->filled('q'), function ($q) use ($request) {
                $needle = '%' . $request->string('q') . '%';
                $q->where(function ($w) use ($needle) {
                    $w->where('name', 'like', $needle)->orWhere('email', 'like', $needle);
                });
            })
            ->when($request->filled('is_active'), fn ($q) => $q->where('is_active', $request->boolean('is_active')))
            ->orderByDesc('id')
            ->paginate(20)
            ->withQueryString();

        return view('admin.users', [
            'users'   => $users,
            'tenants' => $tenants,
            'filters' => [
                'tenant_id' => $request->input('tenant_id'),
                'role'      => $request->input('role'),
                'q'         => $request->input('q'),
                'is_active' => $request->input('is_active'),
            ],
            'editId'  => $request->integer('edit') ?: null,
        ]);
    }

    /**
     * Buat user baru. Validasi kombinasi role ↔ tenant_id:
     *   - super_admin → tenant_id HARUS null
     *   - owner/operator → tenant_id WAJIB ada
     */
    public function store(Request $request)
    {
        $data = $request->validate([
            'name'      => ['required', 'string', 'max:255'],
            'email'     => ['required', 'email', 'max:255', 'unique:users,email'],
            'password'  => ['required', 'string', 'min:8', 'confirmed'],
            'role'      => ['required', Rule::in([User::ROLE_SUPER_ADMIN, User::ROLE_OWNER, User::ROLE_OPERATOR])],
            'tenant_id' => [
                'nullable',
                Rule::requiredIf(fn () => in_array($request->input('role'), [User::ROLE_OWNER, User::ROLE_OPERATOR], true)),
                'exists:tenants,id',
            ],
            'is_active' => ['boolean'],
        ]);

        // Cross-field rule: super_admin tidak boleh terikat tenant. Kalau
        // form mengirim tenant_id (mis. via inspect element), kosongkan.
        if ($data['role'] === User::ROLE_SUPER_ADMIN) {
            $data['tenant_id'] = null;
        }

        $data['is_active'] = $request->boolean('is_active', true);
        $data['password']  = Hash::make($data['password']);

        $user = User::create($data);

        return redirect()
            ->route('admin.users.index')
            ->with('status', "User \"{$user->name}\" berhasil ditambahkan. Password sudah di-set — berikan ke user lewat komunikasi terpisah.");
    }

    /**
     * Update profil user (name, email, role, tenant_id, is_active).
     * Password TIDAK diupdate di sini — pakai endpoint resetPassword terpisah.
     */
    public function update(Request $request, User $user)
    {
        // Cegah admin lock-out dirinya sendiri lewat demote / deactivate.
        if ($request->user()->is($user)) {
            $newRole = $request->input('role');
            if ($newRole !== null && $newRole !== User::ROLE_SUPER_ADMIN) {
                abort(403, 'Tidak bisa menurunkan role akun Anda sendiri — minta super_admin lain.');
            }
            if ($request->has('is_active') && ! $request->boolean('is_active')) {
                abort(403, 'Tidak bisa menonaktifkan akun Anda sendiri.');
            }
        }

        $data = $request->validate([
            'name'      => ['required', 'string', 'max:255'],
            'email'     => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'role'      => ['required', Rule::in([User::ROLE_SUPER_ADMIN, User::ROLE_OWNER, User::ROLE_OPERATOR])],
            'tenant_id' => [
                'nullable',
                Rule::requiredIf(fn () => in_array($request->input('role'), [User::ROLE_OWNER, User::ROLE_OPERATOR], true)),
                'exists:tenants,id',
            ],
            'is_active' => ['boolean'],
        ]);

        if ($data['role'] === User::ROLE_SUPER_ADMIN) {
            $data['tenant_id'] = null;
        }

        $data['is_active'] = $request->boolean('is_active');

        $user->update($data);

        return redirect()
            ->route('admin.users.index', request()->only(['tenant_id', 'role', 'q', 'is_active']))
            ->with('status', "User \"{$user->name}\" berhasil diupdate.");
    }

    /**
     * Reset password user — dipakai kalau user lupa password atau
     * admin mau paksa rotate credential. Tidak ada email notifikasi
     * (out of scope), admin harus mengomunikasikan password baru.
     */
    public function resetPassword(Request $request, User $user)
    {
        if ($request->user()->is($user)) {
            abort(403, 'Reset password akun sendiri lewat halaman profil / ganti password, bukan dari sini.');
        }

        $data = $request->validate([
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user->update([
            'password' => Hash::make($data['password']),
        ]);

        return redirect()
            ->route('admin.users.index', request()->only(['tenant_id', 'role', 'q', 'is_active']))
            ->with('status', "Password untuk \"{$user->email}\" berhasil direset. Berikan password baru ke user lewat komunikasi terpisah.");
    }

    /**
     * Hapus user. Tidak boleh hapus diri sendiri.
     */
    public function destroy(Request $request, User $user)
    {
        if ($request->user()->is($user)) {
            abort(403, 'Tidak bisa menghapus akun Anda sendiri.');
        }

        $name  = $user->name;
        $email = $user->email;
        $user->delete();

        return redirect()
            ->route('admin.users.index', request()->only(['tenant_id', 'role', 'q', 'is_active']))
            ->with('status', "User \"{$name}\" ({$email}) berhasil dihapus.");
    }
}