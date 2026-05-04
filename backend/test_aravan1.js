const { Pool } = require('pg');
const { getPaymentInfo } = require('./utils/paymentInfo');

const pool = new Pool({
  connectionString: 'postgresql://postgres:24994533@localhost:5432/aravan_1'
});

async function test() {
  try {
    const { rows: loanRows } = await pool.query("SELECT loan_id FROM loans WHERE contract_number = 'IMPORT-L-119'");
    if (loanRows.length === 0) {
      console.log('Loan not found in aravan_1');
      process.exit();
    }
    const id = loanRows[0].loan_id;
    
    console.log('Calculating for 24.04.2026 in aravan_1...');
    const info = await getPaymentInfo(pool, id, '2026-04-24');
    console.log('RESULT:', JSON.stringify(info, null, 2));
    
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}

test();
