<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | File ini menyimpan kredensial third-party service (Evolution API, dsb).
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | WA Gateway (n8n webhook-test → Evolution API)
    |--------------------------------------------------------------------------
    |
    | Backend Laravel proxy ke n8n workflow webhook-test. n8n flow internal
    | meneruskan request ke Evolution API. Credential Basic n8n tidak pernah
    | bocor ke browser — semuanya server-side.
    |
    | Lihat .docs/WA-GATEWAY-API.md untuk daftar endpoint & shape response.
    |
    | Per-tenant `instance` name disimpan di tenants.wa_settings JSON dengan
    | format `app-{slug}-{kec_id}` — bukan di sini. Backend pilih instance
    | dari session->lokasi saat kirim pesan.
    |
    */
    'wa_gateway' => [
        'base_url'   => rtrim((string) env('WA_GATEWAY_BASE', ''), '/'),
        // Format: "user:pass" — di-encode base64 → "Authorization: Basic ..."
        'api_key'    => env('WA_GATEWAY_API_KEY'),
        'timeout'    => (int) env('WA_GATEWAY_TIMEOUT', 15),
        // User-Agent Chrome untuk bypass Cloudflare WAF enpii (block GuzzleHttp/7).
        'user_agent' => env(
            'WA_GATEWAY_USER_AGENT',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                . '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        ),
    ],

];
