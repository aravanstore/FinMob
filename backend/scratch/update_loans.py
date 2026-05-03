import re

filepath = r'c:\Projects\FinMob\backend\routes\loans.js'

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

replacement = """const router = require('express').Router();
const auth   = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');
const { getPaymentInfo } = require('../utils/paymentInfo');

const getPool = (req) => getTenantPool(req.client.dbName);

router.get('/', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const { rows } = await pool.query(
      `SELECT
         l.loan_id,
         l.contract_number,
         l.issue_date,
         l.end_date,
         l.loan_amount,
         l.principal_balance,
         l.accrued_interest,
         l.accrued_penalty,
         l.status,
         l.repayment_type,
         l.purpose,
         l.interest_rate_annual,
         l.overdue_interest,
         l.accrued_penalty_od,
         l.accrued_penalty_int,
         CASE
           WHEN l.end_date < CURRENT_DATE AND l.principal_balance > 0 THEN 'Просрочен'
           ELSE l.status
         END AS calculated_status
       FROM loans l
       WHERE l.client_id = $1
         AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
       ORDER BY l.issue_date DESC`,
      [req.client.clientId]
    );

    for (let i = 0; i < rows.length; i++) {
      try {
        const info = await getPaymentInfo(pool, rows[i].loan_id);
        rows[i].board = info;
      } catch (e) {
        console.error('getPaymentInfo error for', rows[i].loan_id, e);
      }
    }

    res.json(rows);
"""

pattern = re.compile(r"const router = require\('express'\)\.Router\(\);\nconst auth   = require\('\.\./middleware/auth'\);\nconst \{ getTenantPool \} = require\('\.\./db/pool'\);\n\n.*?res\.json\(rows\);\n", re.DOTALL)

new_code = pattern.sub(replacement, code)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
    
print("Replaced loans.js")
