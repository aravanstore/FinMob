#!/bin/bash
# Meridian Systems — scaffolding script
# Run from your project root folder (FinMob)

echo "🚀 Creating Meridian Systems project structure..."

# --- Backend (Node.js) ---
mkdir -p backend/routes
mkdir -p backend/middleware
mkdir -p backend/db/migrations

# --- Mobile (Flutter placeholder until flutter create runs) ---
mkdir -p mobile

# --- Infra ---
mkdir -p infra

echo "📁 Folders created."

# --- backend/package.json ---
cat > backend/package.json << 'EOF'
{
  "name": "meridian-backend",
  "version": "1.0.0",
  "description": "Meridian Systems API server",
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
EOF

# --- backend/.env (template) ---
cat > backend/.env << 'EOF'
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=meridian
DB_USER=postgres
DB_PASSWORD=your_password_here
JWT_SECRET=super_secret_key_change_this
EOF

# --- backend/db/pool.js ---
cat > backend/db/pool.js << 'EOF'
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     process.env.DB_PORT,
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

pool.on('connect', () => console.log('✅ PostgreSQL connected'));
pool.on('error',   (err) => console.error('❌ DB error:', err));

module.exports = pool;
EOF

# --- backend/db/migrations/001_client_access.sql ---
cat > backend/db/migrations/001_client_access.sql << 'EOF'
-- Migration 001: client login table
-- Run once against your existing PostgreSQL database

CREATE TABLE IF NOT EXISTS client_access (
  id          SERIAL PRIMARY KEY,
  client_id   VARCHAR(50) UNIQUE NOT NULL,  -- matches your existing clients table
  phone       VARCHAR(20) UNIQUE NOT NULL,
  pin_hash    TEXT NOT NULL,                -- bcrypt hash of 4-digit PIN
  created_at  TIMESTAMP DEFAULT NOW(),
  last_login  TIMESTAMP
);

-- Index for fast login lookup
CREATE INDEX IF NOT EXISTS idx_client_access_phone ON client_access(phone);
EOF

# --- backend/middleware/auth.js ---
cat > backend/middleware/auth.js << 'EOF'
const jwt = require('jsonwebtoken');

module.exports = function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'No token provided' });

  const token = authHeader.split(' ')[1]; // Bearer <token>
  if (!token) return res.status(401).json({ error: 'Malformed token' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.client = decoded; // { clientId, phone }
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
EOF

# --- backend/routes/auth.js ---
cat > backend/routes/auth.js << 'EOF'
const router  = require('express').Router();
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const pool    = require('../db/pool');

// POST /api/auth/login
// Body: { phone: "0700123456", pin: "1234" }
router.post('/login', async (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) return res.status(400).json({ error: 'phone and pin required' });

  try {
    const result = await pool.query(
      'SELECT * FROM client_access WHERE phone = $1',
      [phone]
    );
    const client = result.rows[0];
    if (!client) return res.status(404).json({ error: 'Client not found' });

    const valid = await bcrypt.compare(String(pin), client.pin_hash);
    if (!valid) return res.status(401).json({ error: 'Wrong PIN' });

    // Update last login
    await pool.query(
      'UPDATE client_access SET last_login = NOW() WHERE id = $1',
      [client.id]
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
EOF

# --- backend/routes/loans.js ---
cat > backend/routes/loans.js << 'EOF'
const router = require('express').Router();
const auth   = require('../middleware/auth');
const pool   = require('../db/pool');

// GET /api/loans  — loans for the logged-in client
router.get('/', auth, async (req, res) => {
  try {
    // Adjust table/column names to match YOUR existing FinCore schema
    const result = await pool.query(
      `SELECT id, amount, balance, start_date, end_date, status
       FROM loans
       WHERE client_id = $1
       ORDER BY start_date DESC`,
      [req.client.clientId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/loans/:loanId/schedule — payment schedule
router.get('/:loanId/schedule', auth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT due_date, amount, paid, status
       FROM payment_schedule
       WHERE loan_id = $1
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
EOF

# --- backend/routes/payments.js ---
cat > backend/routes/payments.js << 'EOF'
const router = require('express').Router();
const auth   = require('../middleware/auth');

// POST /api/payments/qr — generate QR for MBank (stub, ready for real integration)
router.post('/qr', auth, async (req, res) => {
  const { loanId, amount } = req.body;
  if (!loanId || !amount) return res.status(400).json({ error: 'loanId and amount required' });

  // TODO: replace with real MBank API call
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
EOF

# --- backend/index.js ---
cat > backend/index.js << 'EOF'
require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/loans',    require('./routes/loans'));
app.use('/api/payments', require('./routes/payments'));

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date() }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🟢 Meridian API running on http://localhost:${PORT}`);
});
EOF

# --- infra/cloudflare-tunnel.yml ---
cat > infra/cloudflare-tunnel.yml << 'EOF'
# Cloudflare Tunnel config
# 1. Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
# 2. Run: cloudflared tunnel login
# 3. Run: cloudflared tunnel create meridian
# 4. Replace YOUR_TUNNEL_ID below and run: cloudflared tunnel --config infra/cloudflare-tunnel.yml run

tunnel: YOUR_TUNNEL_ID
credentials-file: ~/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: api.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
EOF

# --- README.md ---
cat > README.md << 'EOF'
# Meridian Systems

Mobile lending platform for borrower self-service.

## Stack
- **Mobile**: Flutter (Dart)
- **Backend**: Node.js + Express
- **Database**: PostgreSQL (existing FinCore DB)
- **Tunnel**: Cloudflare Tunnel

## Quick Start

### 1. Backend
```bash
cd backend
cp .env .env.local   # edit DB credentials
npm install
npm run dev
```

### 2. Run migration
```bash
psql -U postgres -d meridian -f backend/db/migrations/001_client_access.sql
```

### 3. Flutter (after flutter is installed)
```bash
cd mobile
flutter create . --org com.meridiansystems
flutter run
```

## API Endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/auth/login | — | Login with phone + PIN |
| GET | /api/loans | JWT | Get client loans |
| GET | /api/loans/:id/schedule | JWT | Payment schedule |
| POST | /api/payments/qr | JWT | Generate QR code |
| GET | /health | — | Server status |
EOF

echo ""
echo "✅ Done! Next steps:"
echo "   1. cd backend && npm install"
echo "   2. Edit backend/.env with your PostgreSQL credentials"
echo "   3. Run migration: psql -U postgres -d meridian -f backend/db/migrations/001_client_access.sql"
echo "   4. npm run dev"
echo ""
echo "   For Flutter: cd mobile && flutter create . --org com.meridiansystems"