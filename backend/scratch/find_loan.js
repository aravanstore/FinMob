const { getTenantPool } = require('../db/pool');
async function run() {
    const pool = getTenantPool('boy');
    const res = await pool.query("SELECT loan_id, contract_number FROM loans WHERE contract_number = 'IMPORT-L-119'");
    console.log(res.rows);
    pool.end();
}
run();
