const { getTenantPool } = require('../db/pool');
async function run() {
    const pool = getTenantPool('boy');
    const res = await pool.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'transactions' ORDER BY ordinal_position");
    console.log(res.rows);
    pool.end();
}
run();
