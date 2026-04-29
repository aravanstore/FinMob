# Meridian Systems
 
## Stack
- Mobile: Flutter
- Backend: Node.js + Express
- Database: PostgreSQL
- Tunnel: Cloudflare
 
## Start backend
```
cd backend
npm install
npm run dev
```
 
## API
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/auth/login | вЂ” | Login phone+PIN |
| GET | /api/loans | JWT | Client loans |
| GET | /api/loans/:id/schedule | JWT | Payment schedule |
| POST | /api/payments/qr | JWT | QR for MBank |
| GET | /health | вЂ” | Status |
