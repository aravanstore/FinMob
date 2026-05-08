const { Pool } = require('pg');
require('dotenv').config({ path: 'c:/AURUM/.env' });
const crypto = require('crypto');

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;
const IV_LENGTH = 16;

function encryptData(text) {
  if (!text || !ENCRYPTION_KEY) return null;
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
  let encrypted = cipher.update(text);
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return iv.toString('hex') + ':' + encrypted.toString('hex');
}

const pool = new Pool({
  host: 'localhost',
  user: 'postgres',
  password: '24994533',
  database: 'boy'
});

async function run() {
  try {
    const clientId = '70ad5bd2-64b7-49c7-ab39-51c113266a23';
    const newName = 'Абдуллаева Диерахон Бахриддиновна';
    const encrypted = encryptData(newName);
    
    const text = `UPDATE clients SET full_name = $1, fio_encrypted = $2, updated_at = NOW() WHERE client_id = $3 RETURNING *`;
    const values = [newName, encrypted, clientId];
    
    const res = await pool.query(text, values);
    console.log('--- UPDATE RESULT ---');
    console.log(JSON.stringify(res.rows[0], null, 2));
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

run();
