const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'client_inquiries')")
  .then(r => { console.log('Table exists:', r.rows[0].exists); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
