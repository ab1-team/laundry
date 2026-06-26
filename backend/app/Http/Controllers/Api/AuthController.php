<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\ChangePasswordRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterTenantRequest;
use App\Http\Requests\UpdateProfileRequest;
use App\Http\Resources\TenantResource;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\TenantService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function __construct(private readonly TenantService $tenantService) {}

    /**
     * POST /api/v1/auth/register
     * Register tenant baru + owner account.
     */
    public function register(RegisterTenantRequest $request)
    {
        $tenant = $this->tenantService->registerTenant($request->validated());

        return ApiResponse::success(
            new TenantResource($tenant),
            'Registrasi berhasil. Silakan login.',
            201
        );
    }

    /**
     * POST /api/v1/auth/login
     */
    public function login(LoginRequest $request)
    {
        $credentials = $request->only(['email', 'password']);

        $user = User::with('tenant')->where('email', $credentials['email'])->first();

        if (!$user || !Hash::check($credentials['password'], $user->password)) {
            return ApiResponse::error('Email atau password salah', 401);
        }

        if (!$user->is_active) {
            return ApiResponse::error('Akun tidak aktif. Hubungi administrator.', 403);
        }

        // Super Admin tidak butuh tenant active
        if (!$user->isSuperAdmin() && $user->tenant) {
            if ($user->tenant->status === \App\Models\Tenant::STATUS_SUSPENDED) {
                return ApiResponse::error('Tenant suspended. Hubungi Super Admin.', 403);
            }
        }

        // Hapus token lama (opsional, satu device = satu token)
        $user->tokens()->delete();

        // Buat token baru
        $token = $user->createToken('api-token')->plainTextToken;

        // Update last_login_at
        $user->update(['last_login_at' => now()]);

        return ApiResponse::success([
            'access_token' => $token,
            'token_type'   => 'Bearer',
            'user'         => new UserResource($user),
        ], 'Login berhasil');
    }

    /**
     * POST /api/v1/auth/logout
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return ApiResponse::success(null, 'Logout berhasil');
    }

    /**
     * GET /api/v1/auth/me
     */
    public function me(Request $request)
    {
        $user = $request->user()->load('tenant');

        return ApiResponse::success([
            'user' => new UserResource($user),
        ]);
    }

    /**
     * PUT /api/v1/auth/password
     * Update password for the authenticated user. The current password is
     * checked inside [ChangePasswordRequest] (so the 422 lands on the
     * `current_password` field). Casting `password => hashed` on the User
     * model hashes the new value on save.
     */
    public function changePassword(ChangePasswordRequest $request)
    {
        $user = $request->user();
        $user->password = $request->validated('password');
        $user->save();

        return ApiResponse::success(null, 'Password berhasil diubah');
    }

    /**
     * PUT /api/v1/auth/profile
     * Update profil user sendiri (name + email). Email divalidasi unique
     * dengan pengecualian untuk user yang sedang login.
     */
    public function updateProfile(UpdateProfileRequest $request)
    {
        $user = $request->user();
        $user->fill($request->validated());
        $user->save();

        return ApiResponse::success(
            new UserResource($user->load('tenant')),
            'Profil berhasil diupdate'
        );
    }
}