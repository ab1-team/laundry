<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login · LaundryAja Admin</title>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #f5f7fa;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            color: #1a1f2e;
        }
        .login-box {
            width: 100%;
            max-width: 380px;
            background: #fff;
            border: 1px solid #e3e6eb;
            border-radius: 10px;
            padding: 32px;
        }
        h1 {
            margin: 0 0 4px;
            font-size: 22px;
            font-weight: 700;
            letter-spacing: -0.02em;
        }
        .subtitle {
            color: #6b7280;
            font-size: 14px;
            margin: 0 0 24px;
        }
        label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 4px; }
        input[type="email"], input[type="password"] {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #e3e6eb;
            border-radius: 6px;
            font-size: 14px;
            margin-bottom: 14px;
            font-family: inherit;
        }
        input:focus { outline: 2px solid #2c3a5e; outline-offset: -1px; }
        button {
            width: 100%;
            padding: 10px;
            background: #2c3a5e;
            color: #fff;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 4px;
        }
        button:hover { background: #1f2a47; }
        .error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #991b1b;
            padding: 10px 12px;
            border-radius: 6px;
            font-size: 13px;
            margin-bottom: 16px;
        }
    </style>
</head>
<body>
    <div class="login-box">
        <h1>LaundryAja Admin</h1>
        <p class="subtitle">Login untuk manage rilis APK.</p>

        @if ($errors->any())
            <div class="error">
                @foreach ($errors->all() as $error)
                    {{ $error }}<br>
                @endforeach
            </div>
        @endif

        <form method="POST" action="{{ route('admin.login.attempt') }}">
            @csrf
            <label for="email">Email</label>
            <input id="email" name="email" type="email" value="{{ old('email') }}" autofocus required>

            <label for="password">Password</label>
            <input id="password" name="password" type="password" required>

            <button type="submit">Login</button>
        </form>
    </div>
</body>
</html>