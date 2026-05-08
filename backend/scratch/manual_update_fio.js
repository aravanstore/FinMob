const { Pool } = require('pg');
const crypto = require('crypto');
require('dotenv').config({ path: 'c:/AURUM/.env' });

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;

function encryptData(text) {
    if (!text || !ENCRYPTION_KEY) return null;
    const key = Buffer.from(ENCRYPTION_KEY, 'hex');
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');
    return `${iv.toString('hex')}:${authTag}:${encrypted}`;
}

const pool = new Pool({
  host: 'localhost',
  user: 'postgres',
  password: '24994533',
  database: 'boy'
});

async function update() {
  const newName = 'Абдуллаева Диерахон Ботировна';
  const encrypted = encryptData(newName);
  
  try {
    const res = await pool.query(
      "UPDATE clients SET full_name = $1, fio_encrypted = $2 WHERE client_id = '70ad5bd2-64b7-49c7-ab39-51c113266a23' RETURNING *",
      [newName, encrypted]
    );
    console.log('Update success! New full_name in DB:', res.rows[0].full_name);
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

update();
