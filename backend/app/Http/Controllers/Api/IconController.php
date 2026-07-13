<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Resources\IconResource;
use App\Models\Icon;
use Illuminate\Http\Request;

/**
 * API read-only untuk icon. Icon adalah global asset yang di-manage
 * oleh super_admin via /admin/icons (App\Http\Controllers\Admin\IconController).
 *
 * Frontend (mobile picker) butuh `GET /master/icons` saja — listing
 * semua icon aktif. Owner/operator tidak boleh create/update/delete
 * lewat API; itu cuma lewat panel admin.
 */
class IconController extends Controller
{
    /**
     * GET /api/v1/master/icons
     * Tanpa auth role check — semua user authenticated boleh baca daftar
     * icon. Tanpa pagination: tenant perlu lihat semua opsi picker.
     */
    public function index(Request $request)
    {
        $query = Icon::query();

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        $icons = $query->orderBy('name')->get();

        return ApiResponse::success(
            IconResource::collection($icons),
            'Success'
        );
    }
}