const { Pool } = require('pg');
require('dotenv').config();
const path = require('path');

const pool = new Pool({
  host: process.env.PG_CONTROL_HOST || 'localhost',
  user: process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
  database: 'boy'
});

const { decryptData } = require('../utils/crypto');

async function check() {
  try {
    const res = await pool.query("SELECT full_name, fio_encrypted, fio_bindex FROM clients WHERE client_id = '597672f2-aacb-4fbc-9ed1-95c02baac11e'");
    const row = res.rows[0];
    if (!row) {
      console.log('Client not found');
      return;
    }
    console.log('--- DB ROW ---');
    console.log('full_name:', row.full_name);
    console.log('fio_encrypted:', row.fio_encrypted ? row.fio_encrypted.substring(0, 20) + '...' : 'null');
    console.log('fio_bindex:', row.fio_bindex);
    console.log('Decrypted FIO:', decryptData(row.fio_encrypted));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
