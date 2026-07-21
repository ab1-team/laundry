<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<title>Nota {{ $order->ticket_number }}</title>
<style>
  body { font-family: sans-serif; font-size: 9pt; color: #111; }
  h1 { font-size: 13pt; text-align: center; margin: 0 0 2px; }
  h2 { font-size: 11pt; margin: 8px 0 4px; }
  table { width: 100%; border-collapse: collapse; margin: 4px 0; }
  th { text-align: left; border-bottom: 1px solid #333; padding: 2px 3px; font-weight: bold; }
  td { padding: 2px 3px; vertical-align: top; }
  .num { text-align: right; }
  .total td { border-top: 1px solid #333; font-weight: bold; }
  .meta { margin: 6px 0; line-height: 1.4; }
  .small { font-size: 8pt; color: #555; text-align: center; margin-top: 10px; }
  hr.dashed { border: none; border-top: 1px dashed #999; margin: 6px 0; }
</style>
</head>
<body>
  <h1>{{ $tenant->name }}</h1>
  <p class="small">
    {{ $tenant->address }}@if($tenant->city) — {{ $tenant->city }}@endif
    @if($tenant->phone) · {{ $tenant->phone }}@endif
  </p>
  <hr class="dashed">

  <h2>Nota #{{ $order->ticket_number }}</h2>
  <p class="meta">
    Tgl Masuk: {{ $order->created_at->format('d M Y H:i') }}<br>
    @if($order->finished_at)Selesai: {{ $order->finished_at->format('d M Y H:i') }}<br>@endif
    Customer: {{ $customer->name }}<br>
    @if($customer->phone)HP: {{ $customer->phone }}@endif
  </p>

  <table>
    <thead>
      <tr>
        <th>Layanan</th>
        <th class="num">Qty</th>
        <th class="num">Harga</th>
        <th class="num">Sub</th>
      </tr>
    </thead>
    <tbody>
      @foreach($order->items as $item)
      <tr>
        <td>{{ $item->service_name }}</td>
        <td class="num">{{ rtrim(rtrim(number_format((float) $item->qty, 2, ',', '.'), '0'), ',') }} {{ $item->unit }}</td>
        <td class="num">{{ number_format((float) $item->price, 0, ',', '.') }}</td>
        <td class="num">{{ number_format((float) $item->subtotal, 0, ',', '.') }}</td>
      </tr>
      @endforeach
    </tbody>
    <tfoot>
      <tr>
        <td colspan="3" class="num">Subtotal</td>
        <td class="num">{{ number_format((float) $order->subtotal, 0, ',', '.') }}</td>
      </tr>
      @if((float) $order->discount > 0)
      <tr>
        <td colspan="3" class="num">Diskon</td>
        <td class="num">-{{ number_format((float) $order->discount, 0, ',', '.') }}</td>
      </tr>
      @endif
      <tr class="total">
        <td colspan="3" class="num">TOTAL</td>
        <td class="num">Rp {{ number_format((float) $order->total, 0, ',', '.') }}</td>
      </tr>
    </tfoot>
  </table>

  @if($order->notes)
  <p class="meta"><em>Catatan: {{ $order->notes }}</em></p>
  @endif

  <p class="small">Terima kasih atas kepercayaan Anda 🙏</p>
</body>
</html>