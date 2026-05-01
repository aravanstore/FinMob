const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});

p.query("SELECT client_id, full_name FROM clients WHERE client_id::text = '597672f2-aacb-4fbc-9ed1-95c02baac11e'")
  .then(r => { console.log('Client found:', r.rows); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
