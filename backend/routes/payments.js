const router = require('express').Router();
const auth   = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

const getPool = (req) => getTenantPool(req.client.dbName);

/**
 * POST /api/payments/qr
 * Генерация QR-кода для оплаты через MBank
 * Body: { loanId, amount }
 */
router.post('/qr', auth, async (req, res) => {
  const { loanId, amount } = req.body;

  if (!loanId || !amount || Number(amount) <= 0) {
    return res.status(400).json({ error: 'Укажите loanId и сумму' });
  }

  try {
    const pool = getPool(req);

    // Проверяем кредит и получаем баланс
    const { rows } = await pool.query(
      `SELECT loan_id, contract_number, principal_balance, status
       FROM loans
       WHERE loan_id = $1
         AND client_id = $2
         AND (is_deleted = FALSE OR is_deleted IS NULL)
       LIMIT 1`,
      [loanId, req.client.clientId]
    );

    if (!rows.length) {
      return res.status(404).json({ error: 'Кредит не найден' });
    }

    const loan = rows[0];

    if (loan.status === 'Погашен') {
      return res.status(400).json({ error: 'Кредит уже погашен' });
    }

    if (Number(amount) > Number(loan.principal_balance) + 1) {
      return res.status(400).json({
        error: `Сумма превышает остаток долга (${loan.principal_balance} сом)`,
      });
    }

    // QR-код в формате MBank
    // Формат: MERIDIAN|contract_number|amount|clientId|timestamp
    const qrCode = [
      'MERIDIAN',
      loan.contract_number || loanId,
      Number(amount).toFixed(2),
      req.client.clientId,
      Date.now(),
    ].join('|');

    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 минут

    res.json({
      qrCode,
      loanId,
      contractNumber: loan.contract_number,
      amount:         Number(amount),
      balance:        Number(loan.principal_balance),
      clientId:       req.client.clientId,
      expiresAt:      expiresAt.toISOString(),
    });

  } catch (err) {
    console.error('[POST /api/payments/qr]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

/**
 * GET /api/payments/summary
 * Сводка: общий долг, просрочка, ближайший платёж
 */
router.get('/summary', auth, async (req, res) => {
  try {
    const pool = getPool(req);

    const { rows } = await pool.query(
      `SELECT
         COUNT(*)                                    AS total_loans,
         COALESCE(SUM(principal_balance), 0)         AS total_balance,
         COALESCE(SUM(accrued_interest), 0)          AS total_interest,
         COALESCE(SUM(accrued_penalty), 0)           AS total_penalty,
         COUNT(*) FILTER (WHERE end_date < CURRENT_DATE AND principal_balance > 0)
                                                     AS overdue_count
       FROM loans
       WHERE client_id = $1
         AND status NOT IN ('Погашен', 'Закрыт')
         AND (is_deleted = FALSE OR is_deleted IS NULL)`,
      [req.client.clientId]
    );

    // Ближайший платёж по графику
    const { rows: nextPayment } = await pool.query(
      `SELECT ls.payment_date, ls.total_amount, ls.principal_amount, ls.interest_amount,
              l.contract_number
       FROM loan_schedules ls
       JOIN loans l ON l.loan_id = ls.loan_id
       WHERE l.client_id = $1
         AND ls.is_paid = FALSE
         AND ls.payment_date >= CURRENT_DATE
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
       ORDER BY ls.payment_date ASC
       LIMIT 1`,
      [req.client.clientId]
    );

    res.json({
      ...rows[0],
      next_payment: nextPayment[0] || null,
    });

  } catch (err) {
    console.error('[GET /api/payments/summary]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

module.exports = router;
