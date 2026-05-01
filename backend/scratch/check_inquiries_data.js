const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});

p.query("SELECT * FROM client_inquiries")
  .then(r => { console.log('Total inquiries:', r.rows.length); console.log('Rows:', r.rows); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
