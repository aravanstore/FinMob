const { getTenantPool } = require('../db/pool');
async function check() {
  const pool = getTenantPool('boy');
  try {
    const { rows } = await pool.query("SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_enum.enumtypid = pg_type.oid WHERE pg_type.typname = 'client_type_enum' OR pg_type.typname = (SELECT udt_name FROM information_schema.columns WHERE table_name = 'clients' AND column_name = 'client_type' LIMIT 1)");
    console.log(rows.map(r => r.enumlabel));
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}
check();
