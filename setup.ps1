# Meridian Systems — Windows PowerShell setup
# Run from C:\Projects\FinMob in VS Code terminal
 
Write-Host "Creating project structure..." -ForegroundColor Cyan
 
# Folders
$folders = @(
    "backend\routes",
    "backend\middleware",
    "backend\db\migrations",
    "mobile",
    "infra"
)
foreach ($f in $folders) { New-Item -ItemType Directory -Force -Path $f | Out-Null }
Write-Host "Folders created." -ForegroundColor Green
 
# backend\package.json
@'
{
  "name": "meridian-backend",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "jsonwebtoken": "^9.0.2",
    "bcrypt": "^5.1.1",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
'@ | Set-Content backend\package.json -Encoding UTF8
 
# backend\.env
@'
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=meridian
DB_USER=postgres
DB_PASSWORD=your_password_here
JWT_SECRET=super_secret_key_change_this
'@ | Set-Content backend\.env -Encoding UTF8
 
# backend\db\pool.js
@'
const { Pool } = require('pg');
require('dotenv').config();
 
const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     process.env.DB_PORT,
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});
 
pool.on('connect', () => console.log('PostgreSQL connected'));
pool.on('error',   (err) => console.error('DB error:', err));
 
module.exports = pool;
'@ | Set-Content backend\db\pool.js -Encoding UTF8
 
# backend\db\migrations\001_client_access.sql
@'
-- Run once: psql -U postgres -d meridian -f backend/db/migrations/001_client_access.sql
 
CREATE TABLE IF NOT EXISTS client_access (
  id          SERIAL PRIMARY KEY,
  client_id   VARCHAR(50) UNIQUE NOT NULL,
  phone       VARCHAR(20) UNIQUE NOT NULL,
  pin_hash    TEXT NOT NULL,
  created_at  TIMESTAMP DEFAULT NOW(),
  last_login  TIMESTAMP
);
 
CREATE INDEX IF NOT EXISTS idx_client_access_phone ON client_access(phone);
'@ | Set-Content backend\db\migrations\001_client_access.sql -Encoding UTF8
 
# backend\middleware\auth.js
@'
const jwt = require('jsonwebtoken');
 
module.exports = function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'No token provided' });
 
  const token = authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Malformed token' });
 
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.client = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
'@ | Set-Content backend\middleware\auth.js -Encoding UTF8
 
# backend\routes\auth.js
@'
const router = require('express').Router();
const bcrypt = require('bcrypt');
const jwt    = require('jsonwebtoken');
const pool   = require('../db/pool');
 
// POST /api/auth/login  { phone, pin }
router.post('/login', async (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) return res.status(400).json({ error: 'phone and pin required' });
 
  try {
    const result = await pool.query(
      'SELECT * FROM client_access WHERE phone = $1', [phone]
    );
    const client = result.rows[0];
    if (!client) return res.status(404).json({ error: 'Client not found' });
 
    const valid = await bcrypt.compare(String(pin), client.pin_hash);
    if (!valid) return res.status(401).json({ error: 'Wrong PIN' });
 
    await pool.query(
      'UPDATE client_access SET last_login = NOW() WHERE id = $1', [client.id]
    );
 
    const token = jwt.sign(
      { clientId: client.client_id, phone: client.phone },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );
 
    res.json({ token, clientId: client.client_id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});
 
module.exports = router;
'@ | Set-Content backend\routes\auth.js -Encoding UTF8
 
# backend\routes\loans.js
@'
const router = require('express').Router();
const auth   = require('../middleware/auth');
const pool   = require('../db/pool');
 
// GET /api/loans
router.get('/', auth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, amount, balance, start_date, end_date, status
       FROM loans WHERE client_id = $1
       ORDER BY start_date DESC`,
      [req.client.clientId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});
 
// GET /api/loans/:loanId/schedule
router.get('/:loanId/schedule', auth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT due_date, amount, paid, status
       FROM payment_schedule WHERE loan_id = $1
       ORDER BY due_date ASC`,
      [req.params.loanId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});
 
module.exports = router;
'@ | Set-Content backend\routes\loans.js -Encoding UTF8
 
# backend\routes\payments.js
@'
const router = require('express').Router();
const auth   = require('../middleware/auth');
 
// POST /api/payments/qr  { loanId, amount }
router.post('/qr', auth, async (req, res) => {
  const { loanId, amount } = req.body;
  if (!loanId || !amount) return res.status(400).json({ error: 'loanId and amount required' });
 
  const qrPayload = {
    loanId,
    amount,
    clientId: req.client.clientId,
    qrCode: `MBANK:${req.client.clientId}:${loanId}:${amount}:${Date.now()}`,
    expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
  };
 
  res.json(qrPayload);
});
 
module.exports = router;
'@ | Set-Content backend\routes\payments.js -Encoding UTF8
 
# backend\index.js
@'
require('dotenv').config();
const express = require('express');
const cors    = require('cors');
 
const app = express();
app.use(cors());
app.use(express.json());
 
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/loans',    require('./routes/loans'));
app.use('/api/payments', require('./routes/payments'));
 
app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date() }));
 
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Meridian API running on http://localhost:${PORT}`);
});
'@ | Set-Content backend\index.js -Encoding UTF8
 
# infra\cloudflare-tunnel.yml
@'
tunnel: YOUR_TUNNEL_ID
credentials-file: C:\Users\YOUR_USER\.cloudflared\YOUR_TUNNEL_ID.json
 
ingress:
  - hostname: api.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
'@ | Set-Content infra\cloudflare-tunnel.yml -Encoding UTF8
 
# README.md
@'
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
| POST | /api/auth/login | — | Login phone+PIN |
| GET | /api/loans | JWT | Client loans |
| GET | /api/loans/:id/schedule | JWT | Payment schedule |
| POST | /api/payments/qr | JWT | QR for MBank |
| GET | /health | — | Status |
'@ | Set-Content README.md -Encoding UTF8
 
Write-Host ""
Write-Host "Done! All files created." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open backend\.env and set your PostgreSQL password"
Write-Host "  2. cd backend"
Write-Host "  3. npm install"
Write-Host "  4. npm run dev"
Write-Host ""
Write-Host "Then open http://localhost:3000/health in your browser." -ForegroundColor Cyan
 