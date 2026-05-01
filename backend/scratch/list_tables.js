const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")
  .then(r => { console.log(r.rows.map(t=>t.table_name)); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
