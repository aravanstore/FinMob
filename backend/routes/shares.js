const router = require('express').Router();
const auth   = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

const getPool = (req) => getTenantPool(req.client.dbName);

// ─────────────────────────────────────────────────────────────────
// GET /api/shares/summary — сумма паев и дивидендов клиента
// ─────────────────────────────────────────────────────────────────
router.get('/summary', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT 
         COALESCE(share_balance, 0) AS share_balance,
         COALESCE(accrued_dividends, 0) AS accrued_dividends
       FROM clients
       WHERE client_id = $1`,
      [req.client.clientId]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Клиент не найден' });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /api/shares/summary]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────
// GET /api/shares/history — история операций по паям и дивидендам
// ─────────────────────────────────────────────────────────────────
router.get('/history', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         transaction_id,
         transaction_date,
         transaction_type,
         amount,
         description
       FROM transactions
       WHERE client_id = $1
         AND transaction_type IN ('SHARE_DEPOSIT', 'SHARE_WITHDRAW', 'DIVIDEND_PAYOUT', 'Паи')
         AND (is_deleted = FALSE OR is_deleted IS NULL)
       ORDER BY transaction_date DESC, created_at DESC`,
      [req.client.clientId]
    );

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/shares/history]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

module.exports = router;
