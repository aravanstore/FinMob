const { getTenantPool } = require('../db/pool');
async function check() {
  const pool = getTenantPool('boy');
  try {
    const { rows } = await pool.query("SELECT client_id, full_name, LENGTH(photo_base64) as photo_len, SUBSTRING(photo_base64, 1, 30) as photo_start FROM clients WHERE client_id = '746a8b64-a20a-4b6a-8a4d-e44c42118d79'");
    console.log(JSON.stringify(rows, null, 2));
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}
check();
