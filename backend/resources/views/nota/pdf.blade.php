<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<title>Nota {{ $order->ticket_number }}</title>
<style>
  @page { margin: 8px; }
  body { font-family: 'DejaVu Sans Mono', monospace; font-size: 9pt; color: #111; margin: 0; padding: 0; }
  .center { text-align: center; }
  .bold { font-weight: bold; }
  .tenant-name { font-size: 13pt; font-weight: bold; text-align: center; margin: 0 0 2px; font-family: 'DejaVu Sans Mono', monospace; }
  .kop-line { font-size: 8pt; text-align: center; margin: 1px 0; font-family: 'DejaVu Sans Mono', monospace; }
  hr.solid { border: none; border-top: 1px solid #000; margin: 6px 0; }
  hr.dashed { border: none; border-top: 1px dashed #000; margin: 6px 0; }
  .meta-table { width: 100%; border-collapse: collapse; margin: 2px 0; }
  .meta-table td { padding: 1px 0; vertical-align: top; font-size: 8pt; font-family: 'DejaVu Sans Mono', monospace; }
  .meta-label { text-align: left; white-space: nowrap; padding-right: 6px; }
  .meta-value { text-align: right; }
  .meta-colon { padding: 1px 4px; }
  .item-name { font-size: 8pt; margin: 0; font-family: 'DejaVu Sans Mono', monospace; }
  .item-line { font-size: 8pt; font-family: 'DejaVu Sans Mono', monospace; }
  .item-line td { padding: 0; font-size: 8pt; }
  .item-qty { text-align: left; }
  .item-sub { text-align: right; }
  .totals-table { width: 100%; border-collapse: collapse; margin: 2px 0; }
  .totals-table td { padding: 1px 0; font-size: 8pt; font-family: 'DejaVu Sans Mono', monospace; }
  .totals-label { text-align: left; }
  .totals-value { text-align: right; }
  .total-big { font-size: 10pt; font-weight: bold; }
  .footer-line { font-size: 7pt; text-align: center; margin: 1px 0; font-family: 'DejaVu Sans Mono', monospace; }
  .footer-thanks { font-size: 8pt; text-align: center; margin: 4px 0 2px; font-family: 'DejaVu Sans Mono', monospace; }
  .lunas { font-weight: bold; font-size: 9pt; }
</style>
</head>
<body>
  {{-- KOP ATAS --}}
  @if(!empty($tenant->logo_path) && file_exists(public_path('storage/'.$tenant->logo_path)))
  <table style="width:100%;border-collapse:collapse;margin:0 0 2px;">
    <tr>
      <td style="width:48pt;vertical-align:middle;padding:0 4px 0 0;">
        <img src="{{ public_path('storage/'.$tenant->logo_path) }}" style="width:48pt;height:auto;" alt="Logo">
      </td>
      <td style="vertical-align:middle;text-align:center;padding:0;">
        <div class="tenant-name">{{ $tenant->name ?: 'LAUNDRY' }}</div>
        <div class="kop-line">Alamat : {{ $tenant->address }}@if(!empty($tenant->city)), {{ $tenant->city }}@endif</div>
        @if(!empty($tenant->phone))
        <div class="kop-line">Telp : {{ $tenant->phone }}</div>
        @endif
      </td>
    </tr>
  </table>
  @else
  <div class="tenant-name">{{ $tenant->name ?: 'LAUNDRY' }}</div>
  <div class="kop-line">Alamat : {{ $tenant->address }}@if(!empty($tenant->city)), {{ $tenant->city }}@endif</div>
  @if(!empty($tenant->phone))
  <div class="kop-line">Telp : {{ $tenant->phone }}</div>
  @endif
  @endif
  <hr class="solid">

  {{-- META --}}
  <table class="meta-table">
    <tr>
      <td class="meta-label">No</td>
      <td class="meta-colon">:</td>
      <td class="meta-value">{{ $order->ticket_number }}</td>
    </tr>
    <tr>
      <td class="meta-label">Tanggal</td>
      <td class="meta-colon">:</td>
      <td class="meta-value">{{ $order->created_at->format('d/m/Y H:i') }}</td>
    </tr>
    <tr>
      <td class="meta-label">Pelanggan</td>
      <td class="meta-colon">:</td>
      <td class="meta-value">{{ $customer->name }}</td>
    </tr>
    @php $kasirName = $order->createdBy?->name ?? $order->creator?->name ?? null; @endphp
    @if(!empty($kasirName))
    <tr>
      <td class="meta-label">Kasir</td>
      <td class="meta-colon">:</td>
      <td class="meta-value">{{ $kasirName }}</td>
    </tr>
    @endif
  </table>
  <hr class="dashed">

  {{-- ITEMS --}}
  @foreach($order->items as $item)
    <div class="item-name">{{ $item->service_name }}</div>
    <table style="width:100%;border-collapse:collapse;margin-bottom:4px;">
      <tr class="item-line">
        <td class="item-qty">{{ rtrim(rtrim(number_format((float) $item->qty, 2, ',', '.'), '0'), ',') }} {{ $item->unit }} x {{ number_format((float) $item->price, 0, ',', '.') }}</td>
        <td class="item-sub">{{ number_format((float) $item->subtotal, 0, ',', '.') }}</td>
      </tr>
    </table>
  @endforeach
  <hr class="dashed">

  {{-- TOTALS --}}
  <table class="totals-table">
    <tr>
      <td class="totals-label">Subtotal</td>
      <td class="totals-value">{{ number_format((float) $order->subtotal, 0, ',', '.') }}</td>
    </tr>
    @if((float) $order->discount > 0)
    <tr>
      <td class="totals-label">Diskon</td>
      <td class="totals-value">-{{ number_format((float) $order->discount, 0, ',', '.') }}</td>
    </tr>
    @endif
    <tr>
      <td class="totals-label total-big">TOTAL</td>
      <td class="totals-value total-big">{{ number_format((float) $order->total, 0, ',', '.') }}</td>
    </tr>
  </table>
  <hr class="dashed">
  @php
    $totalPaid = method_exists($order, 'totalPaid') ? (float) $order->totalPaid() : 0;
    $remaining = method_exists($order, 'remaining') ? (float) $order->remaining() : ((float) $order->total - $totalPaid);
  @endphp
  <table class="totals-table">
    <tr>
      <td class="totals-label">Dibayar</td>
      <td class="totals-value">{{ number_format($totalPaid, 0, ',', '.') }}</td>
    </tr>
    @if($remaining > 0)
    <tr>
      <td class="totals-label">Sisa</td>
      <td class="totals-value">{{ number_format($remaining, 0, ',', '.') }}</td>
    </tr>
    @else
    <tr>
      <td class="totals-label lunas">LUNAS</td>
      <td class="totals-value lunas">{{ number_format(abs($remaining), 0, ',', '.') }}</td>
    </tr>
    @endif
  </table>

  {{-- FOOTER --}}
  <div class="footer-thanks">
    @if(!empty($tenant->name))
      Terima kasih telah menjadi pelanggan setia "{{ $tenant->name }}"
    @else
      Terima kasih telah menjadi pelanggan setia kami
    @endif
  </div>
  <hr class="dashed">
  <div class="footer-line">Komplain maks 1x24 jam setelah barang diambil</div>
  <div class="footer-line">Dengan membawa struk ini</div>
  <hr class="dashed">
</body>
</html>
