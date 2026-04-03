# ЭкоВыхухоль Mobile

Flutter client for the `ЭкоВыхухоль` project.

## Implemented

- splash and session restore
- login and guest mode
- feed with refresh, pagination, likes, comments count, and views
- post details with live likes and comments
- own profile with stats and own posts
- public profiles of other users
- profile settings
- create and edit post flows
- bottom navigation with feed, map placeholder, events placeholder, and profile

## Run

Install dependencies:

```bash
flutter pub get
```

Start the backend through Docker from the server repo:

```bash
docker compose up --build -d
```

Then run Flutter.

If you move Django behind an API subdomain, point mobile there:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

iOS simulator or Windows desktop:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Physical Android over USB with `adb reverse`:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Physical Android over Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000/api/v1
```

## Demo Accounts

- `anna@econizhny.local` / `demo12345`
- `ivan@econizhny.local` / `demo12345`
- `admin@econizhny.local` / `demo12345`

## Verification

```bash
flutter analyze
flutter test
```
