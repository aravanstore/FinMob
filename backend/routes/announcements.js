const router = require('express').Router();
const auth = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

const getPool = (req) => getTenantPool(req.client.dbName);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/announcements/active — Получить активное объявление для заёмщика
// ─────────────────────────────────────────────────────────────────────────────
router.get('/active', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    
    // Создаем таблицу, если нет
    await pool.query(`
      CREATE TABLE IF NOT EXISTS announcements (
        id SERIAL PRIMARY KEY,
        client_id TEXT, -- NULL для всех
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Ищем объявление: либо общее (client_id IS NULL), либо персональное
    const { rows } = await pool.query(
      `SELECT * FROM announcements 
       WHERE is_active = true 
       AND (client_id IS NULL OR client_id = $1)
       ORDER BY created_at DESC 
       LIMIT 1`,
      [req.client.clientId]
    );

    res.json(rows[0] || null);
  } catch (err) {
    console.error('GET /api/announcements/active error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/announcements — Создать новое объявление (для админки)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', auth, async (req, res) => {
  if (req.client.role !== 'staff' && req.client.role !== 'admin') {
    return res.status(403).json({ error: 'Нет доступа' });
  }

  const { client_id, title, message } = req.body;
  if (!title || !message) return res.status(400).json({ error: 'Заголовок и текст обязательны' });

  try {
    const pool = getPool(req);
    
    // Сначала деактивируем старые (чтобы не было кучи окон)
    if (!client_id) {
       await pool.query(`UPDATE announcements SET is_active = false WHERE client_id IS NULL`);
    } else {
       await pool.query(`UPDATE announcements SET is_active = false WHERE client_id = $1`, [client_id]);
    }

    const { rows } = await pool.query(
      `INSERT INTO announcements (client_id, title, message) VALUES ($1, $2, $3) RETURNING *`,
      [client_id || null, title, message]
    );

    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
