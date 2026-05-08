const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.PG_CONTROL_HOST || 'localhost',
  user: process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
  database: 'boy'
});

async function check() {
  try {
    const res = await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'clients'");
    console.log(res.rows.map(x => x.column_name).join(', '));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
