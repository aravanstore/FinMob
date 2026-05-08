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
    const res = await pool.query("SELECT client_id, full_name FROM clients WHERE full_name ILIKE '%Бахриддин%'");
    console.log('--- MATCHING CLIENTS ---');
    res.rows.forEach(r => console.log(`${r.full_name} (ID: ${r.client_id})`));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
