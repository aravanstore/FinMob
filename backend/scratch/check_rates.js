const { getTenantPool } = require('../db/pool');
async function run() {
    const pool = getTenantPool('boy');
    const res = await pool.query("SELECT interest_rate_annual, penalty_rate_annual, penalty_type, penalty_rate_daily FROM loans WHERE contract_number = 'IMPORT-L-119'");
    console.log(res.rows);
    pool.end();
}
run();
