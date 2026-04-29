const { Client } = require('pg');
async function run() {
  const c = new Client({ user: 'postgres', password: '24994533', database: 'boy' });
  await c.connect();
  const res = await c.query(`
    SELECT
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
      CASE
        WHEN l.end_date < CURRENT_DATE AND l.principal_balance > 0 THEN 'Просрочен'
        ELSE l.status
      END AS calculated_status
    FROM loans l
    WHERE l.client_id = (SELECT client_id FROM clients WHERE inn = '23008197600853' LIMIT 1)
      AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
    ORDER BY l.issue_date DESC
  `);
  console.log(JSON.stringify(res.rows, null, 2));
  await c.end();
}
run().catch(e => console.log('Error:', e.message));
