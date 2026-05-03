require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { getTenantPool } = require('../db/pool');
const bcrypt = require('bcrypt');

async function main() {
  const pool = getTenantPool('boy');
  const { rows } = await pool.query(
    "SELECT username, role, password_hash FROM users WHERE username='admin' LIMIT 1"
  );
  if (!rows.length) { console.log('User not found'); process.exit(1); }
  const u = rows[0];
  console.log('Username:', u.username, '| Role:', u.role);
  console.log('Hash prefix:', u.password_hash?.substring(0, 10));

  const checks = ['1234', 'admin', '123456', 'password', '111111', 'qwerty'];
  for (const pw of checks) {
    const ok = await bcrypt.compare(pw, u.password_hash);
    if (ok) console.log('✅ Password matches:', pw);
  }
  console.log('Done');
  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
