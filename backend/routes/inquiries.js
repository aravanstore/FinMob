const router  = require('express').Router();
console.log('--- INQUIRIES ROUTE LOADED ---');
const auth    = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

const getPool = (req) => getTenantPool(req.client.dbName);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/inquiries — Отправить обращение (от заёмщика)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', auth, async (req, res) => {
  console.log('[POST /api/inquiries] Request received');
  console.log('Client:', req.client);
  console.log('Body:', req.body);
  
  const { type, message } = req.body;

  if (!message || message.trim().length < 5) {
    return res.status(400).json({ error: 'Сообщение слишком короткое' });
  }

  try {
    const pool = getPool(req);
    
    // Создаем таблицу или обновляем тип колонки
    await pool.query(`
      CREATE TABLE IF NOT EXISTS client_inquiries (
        inquiry_id SERIAL PRIMARY KEY,
        client_id TEXT,
        type TEXT DEFAULT 'GENERAL',
        message TEXT NOT NULL,
        status TEXT DEFAULT 'NEW',
        reply_message TEXT,
        replied_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      -- На всякий случай меняем тип и добавляем колонки
      DO $$ 
      BEGIN 
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='client_inquiries' AND column_name='reply_message') THEN
          ALTER TABLE client_inquiries ADD COLUMN reply_message TEXT;
          ALTER TABLE client_inquiries ADD COLUMN replied_at TIMESTAMP;
        END IF;
        IF (SELECT data_type FROM information_schema.columns WHERE table_name = 'client_inquiries' AND column_name = 'client_id') = 'integer' THEN
          ALTER TABLE client_inquiries ALTER COLUMN client_id TYPE TEXT;
        END IF;
      END $$;
    `);

    await pool.query(
      `INSERT INTO client_inquiries (client_id, type, message) VALUES ($1, $2, $3)`,
      [req.client.clientId, type || 'GENERAL', message]
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
// GET /api/inquiries — Список обращений (для админки или личный список заёмщика)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    
    await pool.query(`
      CREATE TABLE IF NOT EXISTS client_inquiries (
        inquiry_id SERIAL PRIMARY KEY,
        client_id TEXT,
        type TEXT DEFAULT 'GENERAL',
        message TEXT NOT NULL,
        status TEXT DEFAULT 'NEW',
        reply_message TEXT,
        replied_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    let queryStr;
    let params = [];

    if (req.client.role === 'staff' || req.client.role === 'admin') {
      // Сотрудник видит всё с именами клиентов
      queryStr = `
        SELECT i.*, c.full_name, c.phone_main 
        FROM client_inquiries i
        JOIN clients c ON i.client_id::text = c.client_id::text
        ORDER BY i.created_at DESC
      `;
    } else {
      // Заёмщик видит только свои
      queryStr = `
        SELECT * FROM client_inquiries 
        WHERE client_id::text = $1
        ORDER BY created_at DESC
      `;
      params.push(req.client.clientId);
    }

    const { rows } = await pool.query(queryStr, params);
    console.log(`[GET /api/inquiries] Found ${rows.length} rows for client ${req.client.clientId} (role: ${req.client.role})`);
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/inquiries]', err);
    res.status(500).json({ error: 'Ошибка при получении списка обращений' });
  }
});

// Роут ответа также добавим здесь для симметрии
router.post('/:id/reply', auth, async (req, res) => {
  if (req.client.role !== 'staff' && req.client.role !== 'admin') {
    return res.status(403).json({ error: 'Нет доступа' });
  }
  const { id } = req.params;
  const { message } = req.body;
  try {
    const pool = getPool(req);
    await pool.query(
      `UPDATE client_inquiries SET reply_message = $1, replied_at = NOW(), status = 'CLOSED' WHERE inquiry_id = $2`,
      [message, id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
