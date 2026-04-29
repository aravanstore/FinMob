const router  = require('express').Router();
const auth    = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

// Middleware: только для сотрудников
function staffOnly(req, res, next) {
  if (req.client?.role !== 'staff') {
    return res.status(403).json({ error: 'Доступ только для сотрудников' });
  }
  next();
}

const getPool = (req) => getTenantPool(req.client.dbName);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/clients?search=ФИО_или_ИНН_или_телефон
// Поиск клиентов (на выезде, в центре одобрений)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/clients', auth, staffOnly, async (req, res) => {
  const search = (req.query.search || '').trim();
  const limit  = Math.min(50, parseInt(req.query.limit || '20'));

  if (search.length < 2) {
    return res.status(400).json({ error: 'Введите минимум 2 символа для поиска' });
  }

  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         c.client_id,
         c.full_name,
         c.phone_main,
         c.phone_extra,
         c.inn,
         c.status,
         c.address_factual,
         c.registration_date,
         COUNT(l.loan_id) FILTER (
           WHERE l.status NOT IN ('Погашен','Закрыт')
           AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
         ) AS active_loans_count,
         COALESCE(SUM(l.principal_balance) FILTER (
           WHERE l.status NOT IN ('Погашен','Закрыт')
           AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
         ), 0) AS total_balance
       FROM clients c
       LEFT JOIN loans l ON l.client_id = c.client_id
       WHERE (c.is_deleted = FALSE OR c.is_deleted IS NULL)
         AND (
           c.full_name ILIKE $1
           OR c.phone_main LIKE $2
           OR c.inn = $3
         )
       GROUP BY c.client_id
       ORDER BY c.full_name
       LIMIT $4`,
      [`%${search}%`, `%${search}%`, search, limit]
    );

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/staff/clients]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/clients/:clientId — полная информация о заёмщике
// ─────────────────────────────────────────────────────────────────────────────
router.get('/clients/:clientId', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);

    const { rows: clientRows } = await pool.query(
      `SELECT
         c.*
       FROM clients c
       WHERE c.client_id = $1
         AND (c.is_deleted = FALSE OR c.is_deleted IS NULL)
       LIMIT 1`,
      [req.params.clientId]
    );

    if (!clientRows.length) {
      return res.status(404).json({ error: 'Клиент не найден' });
    }

    const client = clientRows[0];

    // Кредиты клиента
    const { rows: loans } = await pool.query(
      `SELECT
         loan_id, contract_number, issue_date, end_date,
         loan_amount, principal_balance, accrued_interest, accrued_penalty,
         status, repayment_type, purpose, collateral_type, collateral_description,
         CASE
           WHEN end_date < CURRENT_DATE AND principal_balance > 0 THEN 'Просрочен'
           ELSE status
         END AS calculated_status
       FROM loans
       WHERE client_id = $1
         AND (is_deleted = FALSE OR is_deleted IS NULL)
       ORDER BY issue_date DESC`,
      [req.params.clientId]
    );

    // Сводка
    const totalBalance = loans.reduce((s, l) => s + Number(l.principal_balance), 0);
    const totalPenalty = loans.reduce((s, l) => s + Number(l.accrued_penalty), 0);
    const overdueLoans = loans.filter(l => l.calculated_status === 'Просрочен');

    res.json({
      client,
      loans,
      summary: {
        total_loans:    loans.length,
        active_loans:   loans.filter(l => !['Погашен','Закрыт'].includes(l.status)).length,
        total_balance:  totalBalance,
        total_penalty:  totalPenalty,
        overdue_count:  overdueLoans.length,
        overdue_amount: overdueLoans.reduce((s, l) => s + Number(l.principal_balance), 0),
      },
    });
  } catch (err) {
    console.error('[GET /api/staff/clients/:clientId]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/loans/:loanId — полный просмотр кредита сотрудником
// ─────────────────────────────────────────────────────────────────────────────
router.get('/loans/:loanId', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);

    const { rows: loanRows } = await pool.query(
      `SELECT l.*, c.full_name, c.phone_main, c.inn
       FROM loans l
       JOIN clients c ON c.client_id = l.client_id
       WHERE l.loan_id = $1
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
       LIMIT 1`,
      [req.params.loanId]
    );

    if (!loanRows.length) return res.status(404).json({ error: 'Кредит не найден' });

    const loan = loanRows[0];

    // График платежей
    const { rows: schedule } = await pool.query(
      `SELECT *, CASE
         WHEN is_paid = TRUE THEN 'paid'
         WHEN payment_date < CURRENT_DATE THEN 'overdue'
         ELSE 'pending'
       END AS status
       FROM loan_schedules
       WHERE loan_id = $1
       ORDER BY payment_number ASC`,
      [req.params.loanId]
    );

    res.json({ loan, schedule });
  } catch (err) {
    console.error('[GET /api/staff/loans/:loanId]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/overdue — список просроченных (для выездной работы)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/overdue', auth, staffOnly, async (req, res) => {
  const limit = Math.min(100, parseInt(req.query.limit || '50'));

  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         l.loan_id, l.contract_number, l.end_date,
         l.principal_balance, l.accrued_penalty,
         CURRENT_DATE - l.end_date AS days_overdue,
         c.client_id, c.full_name, c.phone_main, c.address_factual
       FROM loans l
       JOIN clients c ON c.client_id = l.client_id
       WHERE l.end_date < CURRENT_DATE
         AND l.principal_balance > 0
         AND l.status NOT IN ('Погашен','Закрыт')
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
         AND (c.is_deleted = FALSE OR c.is_deleted IS NULL)
       ORDER BY days_overdue DESC
       LIMIT $1`,
      [limit]
    );

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/staff/overdue]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

module.exports = router;
