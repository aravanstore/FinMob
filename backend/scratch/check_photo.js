const { getTenantPool } = require('../db/pool');
async function check() {
  const pool = getTenantPool('boy');
  try {
    const { rows } = await pool.query("SELECT client_id, full_name, LENGTH(photo_base64) as photo_len FROM clients ORDER BY created_at DESC LIMIT 1");
    console.log(JSON.stringify(rows, null, 2));
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}
check();
