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
    const res = await pool.query("SELECT is_deleted FROM clients WHERE client_id = '70ad5bd2-64b7-49c7-ab39-51c113266a23'");
    console.log('is_deleted value:', res.rows[0].is_deleted);
    console.log('is_deleted type:', typeof res.rows[0].is_deleted);
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
