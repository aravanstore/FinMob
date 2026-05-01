const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("UPDATE loans SET status = 'На рассмотрении' WHERE loan_id = (SELECT loan_id FROM loans LIMIT 1)")
  .then(r => { console.log('Updated 1 row for test'); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
