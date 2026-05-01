const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});

async function test() {
  try {
    const search = '';
    const limit = 20;
    const { rows } = await p.query(
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
           OR c.phone_main LIKE $2
           OR c.inn = $3
         )
       GROUP BY c.client_id
       ORDER BY c.full_name
       LIMIT $4`,
      [`%${search}%`, `%${search}%`, search, limit]
    );
    console.log('Success, rows:', rows.length);
  } catch (err) {
    console.error('Error in search:', err);
  }

  try {
    const { rows } = await p.query(
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
    console.log('Success approvals, rows:', rows.length);
  } catch (err) {
    console.error('Error in approvals:', err);
  }
  process.exit(0);
}
test();
