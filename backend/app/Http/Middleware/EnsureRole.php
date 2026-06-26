<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureRole
{
    /**
     * Ensure the authenticated user has one of the given roles.
     * Usage: ->middleware('role:owner,operator')
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated',
            ], 401);
        }

        if (!$user->hasRole($roles)) {
            return response()->json([
                'success' => false,
                'message' => 'Forbidden. Role tidak diizinkan.',
            ], 403);
        }

        return $next($request);
    }
}