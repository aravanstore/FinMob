const { getTenantPool } = require('./db/pool');
async function check() {
  const pool = getTenantPool('boy');
  try {
    const { rows } = await pool.query('SELECT * FROM announcements ORDER BY created_at DESC LIMIT 5');
    console.log(JSON.stringify(rows, null, 2));
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}
check();
