const { controlPool, getTenantPool } = require('../db/pool');

async function backfillNextPaymentDate() {
  try {
    const { rows: tenants } = await controlPool.query("SELECT name, pg_database FROM tenants WHERE status = 'active'");
    console.log(`Starting backfill for ${tenants.length} tenants...\n`);

    for (const tenant of tenants) {
      const pool = getTenantPool(tenant.pg_database);
      console.log(`Processing Tenant: ${tenant.name} (${tenant.pg_database})`);
      
      try {
        // Проверяем наличие колонок
        const { rows: columns } = await pool.query(`
          SELECT column_name FROM information_schema.columns 
          WHERE table_name = 'loans' AND column_name = 'next_payment_date'
        `);
        
        if (columns.length === 0) {
          console.log(`  Skipping: next_payment_date column does not exist.`);
          continue;
        }

        // Обновляем next_payment_date для всех активных займов
        const updateResult = await pool.query(`
          UPDATE loans l
          SET next_payment_date = (
            SELECT MIN(payment_date)
            FROM loan_schedules s
            WHERE s.loan_id = l.loan_id 
              AND (s.is_paid = FALSE OR s.is_paid IS NULL)
              AND (s.is_deleted = FALSE OR s.is_deleted IS NULL)
          )
          WHERE l.status NOT IN ('Погашен', 'Закрыт', 'Отказан')
            AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
        `);
        
        console.log(`  Updated ${updateResult.rowCount} loans.`);
      } catch (err) {
        console.error(`  Error in tenant ${tenant.name}:`, err.message);
      }
    }
    console.log('\nBackfill completed.');
    process.exit(0);
  } catch (err) {
    console.error('Fatal Error:', err);
    process.exit(1);
  }
}

backfillNextPaymentDate();
