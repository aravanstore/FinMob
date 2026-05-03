require('dotenv').config();
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'boy',
  user: 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
});

async function main() {
  const newPassword = 'admin123';
  const hash = await bcrypt.hash(newPassword, 10);

  const { rows } = await pool.query(
    "UPDATE users SET password_hash = $1 WHERE username = 'admin' RETURNING username, role",
    [hash]
  );
  console.log('✅ Password reset for:', JSON.stringify(rows));
  console.log('   New password:', newPassword);
  await pool.end();
}

main().catch(e => { console.error('ERROR:', e.message); pool.end(); });
