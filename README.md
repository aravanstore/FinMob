# Meridian Systems
 
## Stack
- Mobile: Flutter
- Backend: Node.js + Express
- Database: PostgreSQL
- Tunnel: Cloudflare
 
## Как стартануть (Windows / PowerShell)

### 0) Требования
- Flutter SDK: `flutter doctor -v` без ошибок по Android toolchain
- Node.js LTS + npm
- PostgreSQL (локально) **или** Docker Desktop

> Примечание: в PowerShell оператор `&&` может не работать. Команды ниже запускай **по одной строке**.

### 1) Backend (порт 3002)

Вариант A — через `npm`:

```
cd backend
npm install
npm run dev
```

Вариант B — батник:

```
start_backend.bat
```

Проверка:

```
http://localhost:3002/health
```

### 2) База данных (PostgreSQL)

Если поднимать Postgres через Docker:

```
cd infra
docker compose up -d
```

### 3) Mobile (Flutter)

```
cd mobile
flutter pub get
flutter run
```

#### Важно про адрес API в Android-эмуляторе
Для Android emulator backend на твоём ПК доступен как:

```
http://10.0.2.2:3002
```

Сейчас это прописано в мобильном клиенте (см. `mobile/lib/services/api_service.dart` → `devUrl`).

## Start backend
```
cd backend
npm install
npm run dev
```
 
## API
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/auth/login | — | Login phone+PIN |
| GET | /api/loans | JWT | Client loans |
| GET | /api/loans/:id/schedule | JWT | Payment schedule |
| POST | /api/payments/qr | JWT | QR for MBank |
| GET | /health | — | Status |
