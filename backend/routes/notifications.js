// ─────────────────────────────────────────────────────────────────────────────
// notifications.js — роут для push-уведомлений
// Подключить в index.js:
//   app.use('/api/notifications', require('./routes/notifications'));
// ─────────────────────────────────────────────────────────────────────────────
const router = require('express').Router();
const auth   = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');
const admin  = require('firebase-admin');

const getPool = (req) => getTenantPool(req.client.dbName);

// ─── Создаём таблицу fcm_tokens при первом обращении ─────────────────────────
const initializedDbs = new Set();
async function ensureFcmTable(pool, dbName) {
  if (initializedDbs.has(dbName)) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS fcm_tokens (
      token_id    SERIAL PRIMARY KEY,
      client_id   TEXT NOT NULL,
      fcm_token   TEXT NOT NULL,
      device_info TEXT,
      created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(client_id, fcm_token)
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_fcm_tokens_client_id ON fcm_tokens(client_id)
  `);
  initializedDbs.add(dbName);
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/notifications/token
// Клиент сохраняет свой FCM токен после логина или обновления
// ─────────────────────────────────────────────────────────────────────────────
router.post('/token', auth, async (req, res) => {
  const { fcm_token, device_info } = req.body;
  if (!fcm_token) return res.status(400).json({ error: 'fcm_token обязателен' });

  try {
    const pool = getPool(req);
    await ensureFcmTable(pool, req.client.dbName);

    // Upsert: если токен уже есть — обновляем updated_at, иначе вставляем
    await pool.query(`
      INSERT INTO fcm_tokens (client_id, fcm_token, device_info, updated_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (client_id, fcm_token)
      DO UPDATE SET updated_at = NOW(), device_info = EXCLUDED.device_info
    `, [String(req.client.clientId), fcm_token, device_info || null]);

    res.json({ success: true });
  } catch (err) {
    console.error('[POST /api/notifications/token]', err);
    res.status(500).json({ error: 'Ошибка сохранения токена' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/notifications/token
// Удаляем токен при выходе из аккаунта (logout)
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/token', auth, async (req, res) => {
  const { fcm_token } = req.body;
  if (!fcm_token) return res.status(400).json({ error: 'fcm_token обязателен' });

  try {
    const pool = getPool(req);
    await pool.query(
      `DELETE FROM fcm_tokens WHERE client_id = $1 AND fcm_token = $2`,
      [String(req.client.clientId), fcm_token]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('[DELETE /api/notifications/token]', err);
    res.status(500).json({ error: 'Ошибка удаления токена' });
  }
});

module.exports = router;
