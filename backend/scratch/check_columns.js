const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT * FROM chart_of_accounts LIMIT 1")
  .then(r => { console.log('chart_of_accounts columns:', Object.keys(r.rows[0])); })
  .then(() => p.query("SELECT * FROM account_balances LIMIT 1"))
  .then(r => { console.log('account_balances columns:', Object.keys(r.rows[0])); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
