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
    const res = await pool.query("SELECT client_id, full_name, client_type FROM clients WHERE client_id = '70ad5bd2-64b7-49c7-ab39-51c113266a23'");
    console.log('--- CLIENT DATA ---');
    console.log(JSON.stringify(res.rows[0], null, 2));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
