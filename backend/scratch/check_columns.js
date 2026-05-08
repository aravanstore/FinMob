const { Pool } = require('pg');
require('dotenv').config({ path: 'c:/AURUM/.env' });

const pool = new Pool({
  host: 'localhost',
  user: 'postgres',
  password: '24994533',
  database: 'boy'
});

async function check() {
  try {
    const res = await pool.query(
      "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'clients'"
    );
    console.log('--- COLUMNS ---');
    res.rows.forEach(r => console.log(`${r.column_name} (${r.data_type})`));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
