<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateTenant
{
    /**
     * Ensure the authenticated user belongs to an active tenant.
     * Super Admin bypasses this check.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated',
            ], 401);
        }

        // Super Admin tidak butuh tenant
        if ($user->isSuperAdmin()) {
            return $next($request);
        }

        // User harus punya tenant
        if (!$user->tenant_id) {
            return response()->json([
                'success' => false,
                'message' => 'User tidak terkait dengan tenant manapun',
            ], 403);
        }

        // Tenant harus ada
        $tenant = $user->tenant;

        if (!$tenant) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant tidak ditemukan',
            ], 404);
        }

        // Tenant harus active
        if ($tenant->status === \App\Models\Tenant::STATUS_SUSPENDED) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant suspended. Hubungi Super Admin.',
            ], 403);
        }

        // Set tenant context ke request
        $request->attributes->set('tenant', $tenant);

        return $next($request);
    }
}