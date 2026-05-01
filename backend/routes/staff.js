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

  // Если поиск пустой, просто возвращаем список последних клиентов

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
           $1::text = '%%'
           OR c.full_name ILIKE $1
           OR c.phone_main ILIKE $1
           OR c.inn::text ILIKE $1
         )
       GROUP BY 
         c.client_id, 
         c.full_name, 
         c.phone_main, 
         c.phone_extra, 
         c.inn, 
         c.status, 
         c.address_factual, 
         c.registration_date
       ORDER BY c.full_name
       LIMIT $2`,
      [`%${search}%`, limit]
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

    // История реальных платежей (транзакций) - исключаем начисления
    const { rows: payments } = await pool.query(
      `SELECT transaction_id, transaction_date, amount, description
       FROM transactions
       WHERE loan_id = $1
         AND (is_deleted = FALSE OR is_deleted IS NULL)
         AND transaction_type NOT IN ('INTEREST_ACCRUAL', 'PENALTY_ACCRUAL', 'ACCRUAL')
         AND description NOT LIKE '%начисление%'
       ORDER BY transaction_date DESC, created_at DESC`,
      [req.params.loanId]
    );

    res.json({ loan, schedule, payments });
  } catch (err) {
    console.error('[GET /api/staff/loans/:loanId]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/clients/:clientId/shares — история паёв клиента для сотрудника
// ─────────────────────────────────────────────────────────────────────────────
router.get('/clients/:clientId/shares', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         transaction_id, transaction_date, transaction_type, amount, description
       FROM transactions
       WHERE client_id = $1
         AND transaction_type IN ('SHARE_DEPOSIT', 'SHARE_WITHDRAW', 'DIVIDEND_PAYOUT', 'Паи')
         AND (is_deleted = FALSE OR is_deleted IS NULL)
       ORDER BY transaction_date DESC, created_at DESC`,
      [req.params.clientId]
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/staff/clients/:clientId/shares]', err);
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

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/approvals — список кредитов на рассмотрении (одобрения)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/approvals', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         l.loan_id, l.loan_amount, l.issue_date, l.status, l.purpose,
         c.client_id, c.full_name, c.phone_main
       FROM loans l
       JOIN clients c ON c.client_id = l.client_id
       WHERE l.status IN ('На рассмотрении', 'Ожидает одобрения', 'Заявка', 'Новая')
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
         AND (c.is_deleted = FALSE OR c.is_deleted IS NULL)
       ORDER BY l.issue_date DESC`
    );

    res.json(rows);
  } catch (err) {
    console.error('[GET /api/staff/approvals]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/dashboard-stats — общая статистика (касса, корсчет и т.д.)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/dashboard-stats', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);

    // Получаем последние остатки по счетам 10001 (Касса) и 10101 (Корсчет)
    const { rows } = await pool.query(
      `SELECT
         account_code,
         debit_balance,
         credit_balance
       FROM account_balances
       WHERE account_code IN ('10001', '10101')
       ORDER BY balance_date DESC, created_at DESC
       LIMIT 2`
    );

    let cash = 0;
    let bank = 0;

    for (const row of rows) {
      if (row.account_code === '10001') {
        cash = Number(row.debit_balance) - Number(row.credit_balance);
      } else if (row.account_code === '10101') {
        bank = Number(row.debit_balance) - Number(row.credit_balance);
      }
    }

    res.json({
      cash_balance: cash,
      bank_balance: bank,
    });
  } catch (err) {
    console.error('[GET /api/staff/dashboard-stats]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

module.exports = router;
