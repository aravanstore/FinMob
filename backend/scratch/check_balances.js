const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT * FROM account_balances WHERE account_code IN ('10001', '10101') ORDER BY balance_date DESC LIMIT 4")
  .then(r => { console.log(r.rows); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
