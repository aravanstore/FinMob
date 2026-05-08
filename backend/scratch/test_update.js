const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.PG_CONTROL_HOST || 'localhost',
  user: process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
  database: 'boy'
});

const { encryptData, getBlindIndex, decryptData } = require('../utils/crypto');

async function testUpdate() {
  const clientId = '597672f2-aacb-4fbc-9ed1-95c02baac11e';
  const newName = 'Абдуллаев Бахриддин Ботирович';
  
  try {
    const fioEnc = encryptData(newName);
    const fioBindex = getBlindIndex(newName);
    
    console.log('Updating client...');
    await pool.query(
      "UPDATE clients SET fio_encrypted = $1, fio_bindex = $2, full_name = $3 WHERE client_id = $4",
      [fioEnc, fioBindex, newName, clientId]
    );
    
    console.log('Update done. Reading back...');
    const res = await pool.query("SELECT full_name, fio_encrypted FROM clients WHERE client_id = $1", [clientId]);
    const row = res.rows[0];
    console.log('full_name:', row.full_name);
    console.log('Decrypted FIO:', decryptData(row.fio_encrypted));
    
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

testUpdate();
