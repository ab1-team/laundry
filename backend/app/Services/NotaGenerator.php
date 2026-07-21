<?php

namespace App\Services;

use App\Models\Order;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\Storage;

/**
 * Render struk PDF untuk satu order, simpan ke `local` disk, return path.
 *
 * Output: `nota/order-{id}.pdf` di `storage/app/private/`.
 * Caller (SendWaNotificationJob) baca file → base64 → kirim via Evolution
 * `sendMedia` (data URL, no public URL needed).
 *
 * Skipped: QR code (lib tambahan), logo tenant (butuh upload + resize),
 * multi-page, custom paper size per-tenant. Add when ada permintaan.
 */
class NotaGenerator
{
    public function generate(Order $order): string
    {
        $order->loadMissing(['items', 'customer', 'tenant']);

        $pdf = Pdf::loadView('nota.pdf', [
            'order'    => $order,
            'tenant'   => $order->tenant,
            'customer' => $order->customer,
        ])->setPaper('a6', 'portrait');

        $path = "nota/order-{$order->id}.pdf";
        Storage::disk('local')->put($path, $pdf->output());

        return $path;
    }
}