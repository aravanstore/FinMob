const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});
p.query("SELECT pg_get_constraintdef(c.oid) FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE conrelid = 'loans'::regclass AND contype = 'c';")
  .then(r => { console.log(r.rows); process.exit(0); })
  .catch(e => { console.error(e); process.exit(1); });
