const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const pool = new Pool({
  host:     process.env.PG_CONTROL_HOST || 'localhost',
  port:     parseInt(process.env.PG_CONTROL_PORT || '5432'),
  database: process.env.PG_CONTROL_DB   || 'fincore_control',
  user:     process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
});

async function check() {
  try {
    const res = await pool.query("SELECT * FROM tenants WHERE pg_database = 'boy';");
    console.log('Tenants:', res.rows);
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

check();
