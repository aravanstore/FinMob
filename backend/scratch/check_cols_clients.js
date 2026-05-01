const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'clients'")
  .then(r => { console.log(r.rows.map(c => c.column_name)); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
