const router = require('express').Router();
const auth   = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');
const { getPaymentInfo } = require('../utils/paymentInfo');

const getPool = (req) => getTenantPool(req.client.dbName);

router.get('/', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         l.loan_id,
         l.contract_number,
         l.issue_date,
         l.end_date,
         l.loan_amount,
         l.principal_balance,
         l.accrued_interest,
         l.accrued_penalty,
         l.status,
         l.repayment_type,
         l.purpose,
         l.interest_rate_annual,
         l.overdue_interest,
         l.accrued_penalty_od,
         l.accrued_penalty_int,
         CASE
           WHEN l.end_date < CURRENT_DATE AND l.principal_balance > 0 THEN 'Просрочен'
           ELSE l.status
         END AS calculated_status
       FROM loans l
       WHERE l.client_id = $1
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
       ORDER BY l.issue_date DESC`,
      [req.client.clientId]
    );

    for (let i = 0; i < rows.length; i++) {
      try {
        const info = await getPaymentInfo(pool, rows[i].loan_id);
        console.log(`[DEBUG] Loan ${rows[i].loan_id} board successfully calculated!`);
        rows[i].board = info;
      } catch (e) {
        console.error('[DEBUG] getPaymentInfo error for', rows[i].loan_id, e);
      }
    }

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/loans]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────
// GET /api/loans/:loanId — детали одного кредита
// ─────────────────────────────────────────────────────────────────
router.get('/:loanId', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         l.*,
         l.interest_rate_annual,
         l.overdue_interest,
         l.accrued_penalty_od,
         l.accrued_penalty_int,
         CASE
           WHEN l.end_date < CURRENT_DATE AND l.principal_balance > 0 THEN 'Просрочен'
           ELSE l.status
         END AS calculated_status
       FROM loans l
       WHERE l.loan_id = $1
         AND l.client_id = $2
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
       LIMIT 1`,
      [req.params.loanId, req.client.clientId]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Кредит не найден' });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error('[GET /api/loans/:loanId]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────
// GET /api/loans/:loanId/schedule — график платежей
// ─────────────────────────────────────────────────────────────────
router.get('/:loanId/schedule', auth, async (req, res) => {
  try {
    const pool = getPool(req);

    // Проверяем что кредит принадлежит клиенту
    const { rows: loanCheck } = await pool.query(
      `SELECT loan_id FROM loans
       WHERE loan_id = $1 AND client_id = $2
         AND (is_deleted = FALSE OR is_deleted IS NULL)`,
      [req.params.loanId, req.client.clientId]
    );

    if (!loanCheck.length) {
      return res.status(404).json({ error: 'Кредит не найден' });
    }

    const { rows } = await pool.query(
      `SELECT
         schedule_id,
         payment_number,
         payment_date,
         principal_amount,
         interest_amount,
         total_amount,
         is_paid,
         paid_date,
         CASE
           WHEN is_paid = TRUE THEN 'paid'
           WHEN payment_date < CURRENT_DATE THEN 'overdue'
           ELSE 'pending'
         END AS status
       FROM loan_schedules
       WHERE loan_id = $1
       ORDER BY payment_number ASC`,
      [req.params.loanId]
    );

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/loans/:loanId/schedule]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────
// GET /api/loans/:loanId/transactions — история операций по кредиту
// ─────────────────────────────────────────────────────────────────
router.get('/:loanId/transactions', auth, async (req, res) => {
  try {
    const pool = getPool(req);

    // Проверяем владельца
    const { rows: loanCheck } = await pool.query(
      `SELECT loan_id FROM loans WHERE loan_id = $1 AND client_id = $2`,
      [req.params.loanId, req.client.clientId]
    );
    if (!loanCheck.length) {
      return res.status(404).json({ error: 'Кредит не найден' });
    }

    const { rows } = await pool.query(
      `SELECT
         transaction_id,
         transaction_date,
         transaction_type,
         amount,
         description
       FROM transactions
       WHERE loan_id = $1
         AND (is_deleted = FALSE OR is_deleted IS NULL)
         AND (description NOT LIKE 'Групповое начисление%' OR description IS NULL)
       ORDER BY transaction_date DESC, created_at DESC
       LIMIT 100`,
      [req.params.loanId]
    );

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/loans/:loanId/transactions]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

module.exports = router;
