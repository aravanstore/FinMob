const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  user: 'postgres',
  password: '24994533',
  database: 'boy'
});

const { decryptData } = require('../utils/crypto');

async function check() {
  try {
    const res = await pool.query("SELECT full_name, fio_encrypted, fio_bindex FROM clients WHERE client_id = '70ad5bd2-64b7-49c7-ab39-51c113266a23'");
    const row = res.rows[0];
    if (!row) {
      console.log('Client not found');
      return;
    }
    console.log('--- DB ROW ---');
    console.log('full_name:', row.full_name);
    console.log('fio_encrypted:', row.fio_encrypted ? row.fio_encrypted.substring(0, 20) + '...' : 'null');
    console.log('Decrypted FIO:', decryptData(row.fio_encrypted));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
