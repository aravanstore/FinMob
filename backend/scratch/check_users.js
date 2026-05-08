const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  user: 'postgres',
  password: '24994533',
  database: 'boy'
});

async function check() {
  try {
    const res = await pool.query("SELECT username, role, password_hash FROM users WHERE is_active = TRUE LIMIT 5");
    console.log('--- USERS ---');
    res.rows.forEach(r => console.log(`${r.username} (${r.role})` || 'no user'));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
