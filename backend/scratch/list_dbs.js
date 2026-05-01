const { Pool } = require('pg');
require('dotenv').config({ path: '../.env' });

const pool = new Pool({
  host:     process.env.PG_CONTROL_HOST || 'localhost',
  port:     parseInt(process.env.PG_CONTROL_PORT || '5432'),
  database: 'postgres',
  user:     process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
});

async function check() {
  try {
    const res = await pool.query('SELECT datname FROM pg_database WHERE datistemplate = false;');
    console.log('Databases:', res.rows.map(r => r.datname));
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

check();
