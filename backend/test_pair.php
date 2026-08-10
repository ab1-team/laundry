<?php
require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;

// Reset wa_settings tenant #1 supaya fresh test
$t1 = \App\Models\Tenant::find(1);
$t1->update(['wa_settings' => null]);

// Owner user
$user = User::query()->where('tenant_id', 1)->first();
echo "user: {$user->email}\n";

$token = $user->createToken('test')->plainTextToken;

// Hit POST /wa-pairing — hanya boleh trigger 1 HTTP call ke n8n (create-instance)
echo "\n--- POST /wa-pairing {number: '081234567890'} ---\n";
$ch = curl_init('http://nginx/api/v1/wa-pairing');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 30,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $token,
        'Accept: application/json',
        'Content-Type: application/json',
    ],
    CURLOPT_POSTFIELDS => json_encode(['number' => '081234567890']),
]);
$resp = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
echo "HTTP $code\n";
$decoded = json_decode($resp, true);
echo json_encode($decoded, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";

// Cek tenant #1 wa_settings setelah hit
$t1f = \App\Models\Tenant::find(1);
echo "\ntenant #1 wa_settings setelah hit:\n";
echo json_encode($t1f->wa_settings, JSON_PRETTY_PRINT) . "\n";

// Bersihkan state test
$t1->update(['wa_settings' => null]);
echo "\n(test cleanup OK)\n";