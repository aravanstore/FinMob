const router  = require('express').Router();
console.log('--- INQUIRIES ROUTE LOADED ---');
const auth    = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

const getPool = (req) => getTenantPool(req.client.dbName);

// ─── Инициализация таблицы ────────────────────────────────────────────────────
async function ensureInquiriesTable(pool) {
  // 1. Создаём таблицу с правильными типами
  await pool.query(`
    CREATE TABLE IF NOT EXISTS client_inquiries (
      inquiry_id    SERIAL PRIMARY KEY,
      client_id     TEXT,
      type          TEXT DEFAULT 'GENERAL',
      message       TEXT NOT NULL,
      status        TEXT DEFAULT 'NEW',
      reply_message TEXT,
      replied_at    TIMESTAMP,
      created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 2. Миграция: если client_id был INTEGER — конвертируем в TEXT
  // ВАЖНО: делаем отдельным запросом, не в DO$$ (надёжнее)
  try {
    const { rows } = await pool.query(`
      SELECT data_type FROM information_schema.columns 
      WHERE table_name = 'client_inquiries' AND column_name = 'client_id'
      LIMIT 1
    `);
    if (rows.length > 0 && rows[0].data_type === 'integer') {
      console.log('[inquiries] Migrating client_id: INTEGER -> TEXT');
      await pool.query(
        `ALTER TABLE client_inquiries ALTER COLUMN client_id TYPE TEXT USING client_id::text`
      );
      console.log('[inquiries] Migration done.');
    }
  } catch (migErr) {
    console.error('[inquiries] Migration error:', migErr.message);
  }

  // 3. Добавляем колонки если их нет (IF NOT EXISTS поддерживается PG 9.6+)
  for (const col of ['reply_message TEXT', 'replied_at TIMESTAMP']) {
    try {
      await pool.query(
        `ALTER TABLE client_inquiries ADD COLUMN IF NOT EXISTS ${col}`
      );
    } catch (_) {}
  }
}

// Кэш: инициализируем таблицу один раз на БД, не на каждый запрос
const initializedDbs = new Set();
async function getReadyPool(req) {
  const pool = getPool(req);
  if (!initializedDbs.has(req.client.dbName)) {
    await ensureInquiriesTable(pool);
    initializedDbs.add(req.client.dbName);
  }
  return pool;
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/inquiries — Отправить обращение (от заёмщика)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', auth, async (req, res) => {
  console.log('[POST /api/inquiries] Client:', req.client?.clientId, 'Body:', req.body);
  const { type, message } = req.body;

  if (!message || message.trim().length < 5) {
    return res.status(400).json({ error: 'Сообщение слишком короткое' });
  }

  try {
    const pool = await getReadyPool(req);
    await pool.query(
      `INSERT INTO client_inquiries (client_id, type, message) VALUES ($1, $2, $3)`,
      [String(req.client.clientId), type || 'GENERAL', message.trim()]
    );
    res.json({ success: true, message: 'Обращение успешно отправлено' });
  } catch (err) {
    const fs = require('fs');
    const logMsg = `[${new Date().toISOString()}] POST /api/inquiries ERROR: ${err.message}\nSTACK: ${err.stack}\nBODY: ${JSON.stringify(req.body)}\nCLIENT: ${JSON.stringify(req.client)}\n\n`;
    fs.appendFileSync('error_log.txt', logMsg);
    console.error('[POST /api/inquiries]', err);
    res.status(500).json({ error: 'Ошибка при отправке обращения: ' + err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/inquiries — Список обращений
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', auth, async (req, res) => {
  try {
    const pool = await getReadyPool(req);
    let queryStr;
    let params = [];

    if (req.client.role === 'staff' || req.client.role === 'admin') {
      queryStr = `
        SELECT i.*, c.full_name, c.phone_main 
        FROM client_inquiries i
        LEFT JOIN clients c ON i.client_id::text = c.client_id::text
        ORDER BY i.created_at DESC
        LIMIT 200
      `;
    } else {
      queryStr = `
        SELECT * FROM client_inquiries 
        WHERE client_id::text = $1
        ORDER BY created_at DESC
      `;
      params.push(String(req.client.clientId));
    }

    const { rows } = await pool.query(queryStr, params);
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/inquiries]', err);
    res.status(500).json({ error: 'Ошибка при получении списка обращений' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/inquiries/:id/reply — Ответить (сотрудник/админ)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/:id/reply', auth, async (req, res) => {
  if (req.client.role !== 'staff' && req.client.role !== 'admin') {
    return res.status(403).json({ error: 'Нет доступа' });
  }
  const { id } = req.params;
  const { message } = req.body;
  if (!message || !message.trim()) {
    return res.status(400).json({ error: 'Текст ответа обязателен' });
  }
  try {
    const pool = await getReadyPool(req);
    const { rowCount } = await pool.query(
      `UPDATE client_inquiries 
       SET reply_message = $1, replied_at = NOW(), status = 'CLOSED' 
       WHERE inquiry_id = $2`,
      [message.trim(), id]
    );
    if (rowCount === 0) return res.status(404).json({ error: 'Обращение не найдено' });
    res.json({ success: true });
  } catch (err) {
    console.error('[POST /api/inquiries/:id/reply]', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
