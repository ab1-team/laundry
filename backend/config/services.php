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
    | Evolution API (WhatsApp gateway)
    |--------------------------------------------------------------------------
    |
    | URL base Evolution API instance (self-hosted atau managed).
    | Token global API key dari Evolution dashboard.
    |
    | Per-tenant `instance` name disimpan di tenants.wa_settings JSON — bukan
    | di sini — supaya multi-tenant bisa share 1 Evolution API server dengan
    | nomor WA berbeda.
    |
    */
    'evolution' => [
        'base_url' => rtrim((string) env('EVOLUTION_API_URL', ''), '/'),
        'api_key'  => env('EVOLUTION_API_KEY'),
        'timeout'  => (int) env('EVOLUTION_API_TIMEOUT', 15),
    ],

];
