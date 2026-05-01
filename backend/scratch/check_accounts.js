const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT * FROM chart_of_accounts WHERE account_number IN ('10001', '10101')")
  .then(r => { console.log('Chart of accounts:', r.rows); })
  .then(() => p.query("SELECT * FROM account_balances WHERE account_number IN ('10001', '10101')"))
  .then(r => { console.log('Balances:', r.rows); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
