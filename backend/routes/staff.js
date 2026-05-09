const router  = require('express').Router();
const auth    = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');
const { getPaymentInfo } = require('../utils/paymentInfo');
const { encryptData, getBlindIndex } = require('../utils/crypto');
const { decryptData } = require('../utils/crypto');

const getPool = (req) => getTenantPool(req.client.dbName);

// Middleware: только для сотрудников
function staffOnly(req, res, next) {
  if (req.client?.role !== 'staff') {
    return res.status(403).json({ error: 'Доступ только для сотрудников' });
  }
  next();
}

const { sendPush } = require('../push_scheduler');

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/staff/clients — создание нового клиента сотрудником
// ─────────────────────────────────────────────────────────────────────────────
router.post('/clients', auth, staffOnly, async (req, res) => {
  try {
    const data = req.body;
    if (data.photo_base64) {
      console.log(`[POST /clients] Получено фото: ${data.photo_base64.length} символов (base64)`);
    } else {
      console.log(`[POST /clients] Фото НЕ получено`);
    }
    const pool = getPool(req);

    // Маппинг типа клиента для ENUM в базе данных
    let clientType = data.client_type || 'individual';
    if (clientType === 'Физ. лицо') clientType = 'individual';
    if (clientType === 'Юр. лицо')  clientType = 'legal_entity';

    const fioEnc = encryptData(data.full_name);
    const innEnc = encryptData(data.inn);
    const fioBindex = getBlindIndex(data.full_name);
    const innBindex = getBlindIndex(data.inn);

    const query = `
      INSERT INTO clients (
        full_name, inn, status, registration_date, client_type,
        gender, date_of_birth, passport_series, passport_number,
        passport_issued_by, passport_issued_date, passport_expiry_date,
        citizenship, address_registration, rural_office, address_factual,
        phone_main, phone_extra, email, workplace, position,
        experience_months, monthly_income, family_status, spouse_name,
        dependents, related_person, uku_sheet, ukz_sheet, notes,
        fio_encrypted, inn_encrypted, fio_bindex, inn_bindex, photo_base64
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, 
        $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
        $31, $32, $33, $34, $35
      ) RETURNING client_id
    `;

    const values = [
      data.full_name, 
      data.inn, 
      data.status || 'Активен', 
      data.registration_date || new Date(), 
      clientType,
      data.gender, 
      data.date_of_birth, 
      data.passport_series, 
      data.passport_number,
      data.passport_issued_by, 
      data.passport_issued_date, 
      data.passport_expiry_date,
      data.citizenship || 'Кыргызстан', 
      data.address_registration, 
      data.rural_office, 
      data.address_factual,
      data.phone_main, 
      data.phone_extra, 
      data.email, 
      data.workplace, 
      data.position,
      data.experience_months || 0, 
      data.monthly_income || 0, 
      data.family_status, 
      data.spouse_name,
      data.dependents || 0, 
      data.related_person || 'Нет', 
      data.uku_sheet, 
      data.ukz_sheet, 
      data.notes,
      fioEnc, 
      innEnc, 
      fioBindex, 
      innBindex,
      data.photo_base64 || null
    ];

    const { rows } = await pool.query(query, values);
    res.json({ success: true, clientId: rows[0].client_id });
  } catch (err) {
    console.error('[POST /api/staff/clients]', err);
    res.status(500).json({ error: 'Ошибка создания клиента: ' + err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/staff/clients/:clientId — частичное обновление данных (паспорт + фото)
// ─────────────────────────────────────────────────────────────────────────────
router.put('/clients/:clientId', auth, staffOnly, async (req, res) => {
  try {
    const { clientId } = req.params;
    const data = req.body;
    const pool = getPool(req);

    // Получаем список колонок, существующих в таблице clients этой БД тенанта
    // (разные тенанты могут иметь разные наборы колонок — photo_base64 добавлена
    //  позже и может отсутствовать в старых базах-копиях)
    const { rows: columns } = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'clients' AND table_schema = 'public'
    `);
    const existingColumns = new Set(columns.map(c => c.column_name));

    // Подготовка зашифрованных данных и индексов для ФИО и ИНН
    const fioEnc = data.full_name ? encryptData(data.full_name) : null;
    const innEnc = data.inn ? encryptData(data.inn) : null;
    const fioBindex = data.full_name ? getBlindIndex(data.full_name) : null;
    const innBindex = data.inn ? getBlindIndex(data.inn) : null;

    const fields = [];
    const values = [];
    let idx = 1;

    // Обрезаем строки до лимита колонки чтобы избежать ошибки 22001
    // (данные из чипа паспорта могут быть длиннее ограничений VARCHAR)
    const str = (val, maxLen) => {
      if (val == null) return val;
      const s = String(val);
      return s.length > maxLen ? s.slice(0, maxLen) : s;
    };

    const addField = (col, val) => {
      if (val !== undefined && val !== null && existingColumns.has(col)) {
        fields.push(`"${col}" = $${idx++}`);
        values.push(val);
      }
    };

    addField('full_name',            str(data.full_name, 255));
    addField('inn',                  str(data.inn, 20));
    addField('passport_series',      str(data.passport_series, 10));
    addField('passport_number',      str(data.passport_number, 20));
    addField('passport_issued_by',   str(data.passport_issued_by, 255));
    addField('passport_issued_date', data.passport_issued_date);
    addField('passport_expiry_date', data.passport_expiry_date);
    addField('gender',               str(data.gender, 20));
    addField('date_of_birth',        data.date_of_birth);
    addField('photo_base64',         data.photo_base64);  // TEXT — без лимита

    if (fioEnc)    addField('fio_encrypted', fioEnc);     // TEXT — без лимита
    if (innEnc)    addField('inn_encrypted', innEnc);     // TEXT — без лимита
    if (fioBindex) addField('fio_bindex',    str(fioBindex, 64));
    if (innBindex) addField('inn_bindex',    str(innBindex, 64));

    if (fields.length === 0) return res.status(400).json({ error: 'Нет данных для обновления' });

    values.push(clientId);
    const query = `UPDATE clients SET ${fields.join(', ')}, updated_at = NOW()
                   WHERE client_id = $${idx}
                     AND (is_deleted = FALSE OR is_deleted IS NULL)
                   RETURNING client_id`;
    
    const { rows } = await pool.query(query, values);
    if (rows.length === 0) return res.status(404).json({ error: 'Клиент не найден' });

    res.json({ success: true, clientId: rows[0].client_id });
  } catch (err) {
    console.error('[PUT /api/staff/clients/:clientId]', err);
    res.status(500).json({ error: 'Ошибка обновления клиента: ' + err.message });
  }
});


// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/clients?search=ФИО_или_ИНН_или_телефон
// Поиск клиентов (на выезде, в центре одобрений)
// FIX: добавлен statement_timeout=8s чтобы не держать соединение вечно
//      (именно зависший запрос вызывал ANR "FinCore isn't responding")
// ─────────────────────────────────────────────────────────────────────────────
router.get('/clients', auth, staffOnly, async (req, res) => {
  const search = (req.query.search || '').trim();
  const limit = Math.min(50, parseInt(req.query.limit || '30'));

  // Общий timeout на весь HTTP-запрос: 10 секунд
  // Если бэкенд не ответил — клиент получает ошибку, а не зависает
  res.setTimeout(10000, () => {
    if (!res.headersSent) {
      res.status(504).json({ error: 'Превышено время ожидания. Попробуйте ещё раз.' });
    }
  });

  const pool = getPool(req);
  let client;

  try {
    client = await pool.connect();
    const qRaw = search.toLowerCase();

    // Устанавливаем statement_timeout именно для этого соединения
    await client.query(`SET LOCAL statement_timeout = '8000'`);

    const SELECT = `SELECT client_id, fio_encrypted, inn_encrypted, full_name, inn, legal_name, phone_main, client_type`;

    const toDto = (r) => ({
      client_id: r.client_id,
      full_name: decryptData(r.fio_encrypted) || r.full_name || 'Без имени',
      inn: decryptData(r.inn_encrypted) || r.inn || '-',
      phone_main: r.phone_main || '',
      legal_name: r.legal_name || '',
      client_type: r.client_type || 'individual',
    });

    let resultRows = [];

    if (!qRaw) {
      const { rows } = await client.query(
        `${SELECT} FROM clients 
         WHERE (is_deleted = FALSE OR is_deleted IS NULL) 
         ORDER BY created_at DESC 
         LIMIT $1`,
        [limit]
      );
      resultRows = rows;
    } else {
      // Быстрый поиск: слепой индекс + ИНН + телефон
      const qBlind = getBlindIndex(search);
      const { rows } = await client.query(
        `${SELECT} FROM clients
         WHERE (is_deleted = FALSE OR is_deleted IS NULL)
           AND (fio_bindex = $1 OR inn_bindex = $1 OR full_name ILIKE $2 OR inn ILIKE $2 OR phone_main ILIKE $2)
         LIMIT $3`,
        [qBlind, `%${search}%`, limit]
      );
      resultRows = rows;
    }

    res.json(resultRows.map(toDto));
  } catch (err) {
    console.error('[GET /api/staff/clients]', err);
    if (!res.headersSent) {
      const isTimeout = err.message?.includes('statement timeout') || err.code === '57014';
      res.status(isTimeout ? 504 : 500).json({
        error: isTimeout
          ? 'Запрос занял слишком много времени. Попробуйте снова.'
          : 'Ошибка сервера при поиске клиентов',
      });
    }
  } finally {
    if (client) client.release();
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
    client.full_name = decryptData(client.fio_encrypted) || client.full_name || 'Без имени';
    client.inn = decryptData(client.inn_encrypted) || client.inn || '-';

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
      `SELECT l.*, c.fio_encrypted, c.inn_encrypted, c.full_name, c.phone_main, c.inn
       FROM loans l
       JOIN clients c ON c.client_id = l.client_id
       WHERE l.loan_id = $1
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
       LIMIT 1`,
      [req.params.loanId]
    );

    if (!loanRows.length) return res.status(404).json({ error: 'Кредит не найден' });

    const loan = loanRows[0];
    loan.full_name = decryptData(loan.fio_encrypted) || loan.full_name || 'Без имени';
    loan.inn = decryptData(loan.inn_encrypted) || loan.inn || '-';

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

    // Добавляем расчётные данные (board) — как в AURUM
    try {
      const board = await getPaymentInfo(pool, loan.loan_id);
      loan.board = board;
    } catch (e) {
      console.error('[staff/loans] getPaymentInfo error:', e.message);
    }

    res.json({ loan, schedule, payments });
  } catch (err) {
    console.error('[GET /api/staff/loans/:loanId]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/staff/loans — оформление нового займа (без выдачи)
// ─────────────────────────────────────────────────────────────────────────────
router.post('/loans', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const { 
      client_id, loan_amount, interest_rate_annual, term_months, repayment_type, 
      issue_date, nbkr_category, purpose, collateral_description, collateral_value, fees_percent 
    } = req.body;
    
    // Генерируем номер договора как в AURUM (КД-YYYYMM-XXX)
    const y = issue_date.substring(0, 4);
    const m = issue_date.substring(5, 7);
    const seq = Math.floor(Math.random() * 900) + 100;
    const contract_number = `КД-${y}${m}-${seq}`;

    // Дата окончания (issue_date + term_months)
    const issueDateObj = new Date(issue_date);
    issueDateObj.setMonth(issueDateObj.getMonth() + (term_months || 1));
    const end_date = issueDateObj.toISOString().split('T')[0];

    // Динамически определяем колонки (как AURUM), чтобы не падать при отсутствии fees_percent
    const { rows: colRows } = await pool.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name = 'loans' AND table_schema = 'public'`
    );
    const existingCols = new Set(colRows.map(r => r.column_name));

    const fields = [
      ['client_id', client_id],
      ['contract_number', contract_number],
      ['loan_amount', loan_amount],
      ['interest_rate_annual', interest_rate_annual],
      ['term_months', term_months],
      ['repayment_type', repayment_type],
      ['issue_date', issue_date],
      ['end_date', end_date],
      ['status', 'Оформлен'],
      ['base_year', 365],
      ['period_od_months', 1],
      ['period_int_months', 1],
      ['nbkr_category', nbkr_category || 'Прочие'],
      ['purpose', purpose || ''],
      ['collateral_description', collateral_description || ''],
      ['collateral_value', collateral_value || 0],
      ['principal_balance', loan_amount],
    ];
    // Опциональные колонки (могут отсутствовать в старых БД)
    if (existingCols.has('fees_percent')) fields.push(['fees_percent', fees_percent || 0]);

    const cols = [];
    const vals = [];
    const placeholders = [];
    for (let i = 0; i < fields.length; i++) {
      const [col, val] = fields[i];
      if (!existingCols.has(col)) continue;
      cols.push(`"${col}"`);
      vals.push(val === '' || (typeof val === 'number' && isNaN(val)) ? null : val);
      placeholders.push(`$${vals.length}`);
    }
    // created_at всегда
    cols.push('created_at');
    vals.push('NOW()');
    // не параметризуем NOW()

    const insertSql = `INSERT INTO loans (${cols.join(', ')}) VALUES (${placeholders.join(', ')}, NOW()) RETURNING loan_id`;
    const { rows } = await pool.query(insertSql, vals);

    res.status(201).json({ success: true, loan_id: rows[0].loan_id });
  } catch (err) {
    console.error('[POST /api/staff/loans]', err);
    res.status(500).json({ error: err.message || 'Ошибка сервера' });
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

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/journal — общий журнал операций для сотрудника
// ─────────────────────────────────────────────────────────────────────────────
router.get('/journal', auth, staffOnly, async (req, res) => {
  const { startDate, endDate, search, accountCode } = req.query;
  const pool = getPool(req);

  try {
    let start = startDate;
    let end = endDate;

    // Если даты не переданы, ищем последние 2 дня, когда были операции
    if (!start || !end) {
      const { rows: dates } = await pool.query(
        `SELECT DISTINCT transaction_date 
         FROM transactions 
         WHERE (is_deleted = FALSE OR is_deleted IS NULL)
         ORDER BY transaction_date DESC 
         LIMIT 2`
      );
      if (dates.length > 0) {
        end = dates[0].transaction_date;
        start = dates[dates.length - 1].transaction_date;
      } else {
        const today = new Date().toISOString().slice(0, 10);
        end = today;
        start = today;
      }
    }

    const query = `
      SELECT 
        t.*, 
        c.full_name as client_name 
      FROM transactions t
      LEFT JOIN clients c ON c.client_id = t.client_id
      WHERE (t.is_deleted = FALSE OR t.is_deleted IS NULL)
        AND t.transaction_date >= $1::date
        AND t.transaction_date <= $2::date
        AND (
          $3::text IS NULL OR 
          c.full_name ILIKE $4 OR 
          t.description ILIKE $4 OR 
          t.transaction_id::text ILIKE $4
        )
        AND (
          $5::text IS NULL OR
          t.debit_account = $5 OR
          t.credit_account = $5
        )
      ORDER BY t.transaction_date DESC, t.created_at DESC
      LIMIT 1000
    `;

    const { rows } = await pool.query(query, [
      start, 
      end, 
      search ? 'search' : null, 
      search ? `%${search}%` : null, 
      accountCode || null
    ]);

    res.json({
      startDate: start,
      endDate: end,
      transactions: rows
    });
  } catch (err) {
    console.error('[GET /api/staff/journal]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/staff/visits — сохранение GPS-метки визита к клиенту
// ─────────────────────────────────────────────────────────────────────────────
router.post('/visits', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    // Убедимся, что таблица существует (для простоты деплоя)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS staff_visits (
        id SERIAL PRIMARY KEY,
        client_id INT REFERENCES clients(client_id),
        staff_id INT,
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    const { client_id, latitude, longitude, notes } = req.body;
    const staff_id = req.user?.userId || req.user?.id || 1; 

    await pool.query(
      `INSERT INTO staff_visits (client_id, staff_id, latitude, longitude, notes)
       VALUES ($1, $2, $3, $4, $5)`,
      [client_id, staff_id, latitude, longitude, notes]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('[POST /api/staff/visits]', err);
    res.status(500).json({ error: 'Ошибка сохранения визита' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/staff/visits — получение списка визитов за сегодня (для руководителя)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/visits', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(`
      SELECT v.*, c.full_name as client_name 
      FROM staff_visits v
      LEFT JOIN clients c ON c.client_id = v.client_id
      WHERE v.created_at::date = CURRENT_DATE
      ORDER BY v.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/staff/visits]', err);
    res.status(500).json({ error: 'Ошибка получения визитов' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Внутренний корпоративный чат (Сотрудник <-> Офис/Другие)
// ─────────────────────────────────────────────────────────────────────────────

router.get('/chat/contacts', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const staffId = req.client.userId;

    const sql = `
      WITH contacts AS (
        SELECT 
          user_id::text as contact_id,
          full_name as contact_name,
          NULL as contact_phone,
          role as contact_type,
          'STAFF' as entity_type
        FROM users
        WHERE is_active = true AND user_id::text != $1
        
        UNION ALL
        
        SELECT 
          client_id::text as contact_id,
          full_name as contact_name,
          phone_main as contact_phone,
          'CLIENT' as contact_type,
          'CLIENT' as entity_type
        FROM clients
        WHERE (is_deleted = FALSE OR is_deleted IS NULL)
      ),
      chat_summary AS (
        SELECT 
          c.contact_id,
          c.contact_name,
          c.contact_phone,
          c.contact_type,
          c.entity_type,
          (
            SELECT message_text 
            FROM internal_chat_messages 
            WHERE 
               (sender_id = c.contact_id AND receiver_id = $1)
               OR (sender_id = $1 AND receiver_id = c.contact_id)
            ORDER BY created_at DESC 
            LIMIT 1
          ) as last_message,
          (
            SELECT created_at 
            FROM internal_chat_messages 
            WHERE 
               (sender_id = c.contact_id AND receiver_id = $1)
               OR (sender_id = $1 AND receiver_id = c.contact_id)
            ORDER BY created_at DESC 
            LIMIT 1
          ) as last_message_date,
          (
            SELECT COUNT(*) 
            FROM internal_chat_messages 
            WHERE sender_id = c.contact_id AND receiver_id = $1 AND is_read = false
          ) as unread_count
        FROM contacts c
      )
      SELECT * FROM chat_summary
      ORDER BY 
        CASE WHEN entity_type = 'STAFF' THEN 0 ELSE 1 END ASC,
        last_message_date DESC NULLS LAST, 
        contact_name ASC
    `;
    
    const { rows } = await pool.query(sql, [String(staffId)]);
    res.json(rows);
  } catch (err) {
    console.error('GET /api/staff/chat/contacts', err);
    res.status(500).json({ error: 'Ошибка получения контактов' });
  }
});

router.get('/chat/history', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const staffId = req.client.userId;
    const { receiverId, receiverType } = req.query;
    
    if (!receiverId || !receiverType) {
        return res.status(400).json({ error: 'receiverId and receiverType required' });
    }

    // Mark messages from this recipient as read
    await pool.query(`
      UPDATE internal_chat_messages 
      SET is_read = true 
      WHERE sender_type = $1 AND sender_id = $2 AND receiver_type = 'STAFF' AND receiver_id = $3
    `, [receiverType, receiverId, String(staffId)]);

    const query = `
      SELECT * FROM internal_chat_messages
      WHERE (sender_type = 'STAFF' AND sender_id = $1 AND receiver_type = $2 AND receiver_id = $3)
         OR (sender_type = $2 AND sender_id = $3 AND receiver_type = 'STAFF' AND receiver_id = $1)
      ORDER BY created_at ASC
      LIMIT 200
    `;
    const { rows } = await pool.query(query, [String(staffId), receiverType, receiverId]);
    res.json(rows);
  } catch (err) {
    console.error('GET /api/staff/chat/history', err);
    res.status(500).json({ error: 'Ошибка получения истории чата' });
  }
});

router.post('/chat/send', auth, staffOnly, async (req, res) => {
  try {
    const pool = getPool(req);
    const staffId = req.client.userId;
    const { messageText, receiverId, receiverType } = req.body;
    
    if (!messageText || !receiverId || !receiverType) {
      return res.status(400).json({ error: 'messageText, receiverId, receiverType обязательны' });
    }

    const query = `
      INSERT INTO internal_chat_messages (sender_type, sender_id, receiver_type, receiver_id, message_text)
      VALUES ('STAFF', $1, $2, $3, $4)
      RETURNING *
    `;
    const { rows } = await pool.query(query, [String(staffId), receiverType, receiverId, messageText]);
    
    // Отправка PUSH-уведомления
    try {
        const { rows: tokens } = await pool.query(
            'SELECT fcm_token FROM fcm_tokens WHERE client_id = $1',
            [String(receiverId)]
        );
        if (tokens.length > 0) {
            const senderName = req.client.fullName || 'Сотрудник';
            for (const t of tokens) {
                await sendPush(t.fcm_token, senderName, messageText, {
                    type: 'chat',
                    sender_id: String(staffId),
                    sender_name: senderName
                });
            }
        }
    } catch (pushErr) {
        console.error('[PUSH Error] Staff Chat:', pushErr.message);
    }

    res.json({ success: true, message: rows[0] });
  } catch (err) {
    console.error('POST /api/staff/chat/send', err);
    res.status(500).json({ error: 'Ошибка отправки сообщения' });
  }
});

module.exports = router;
