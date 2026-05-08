const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.PG_CONTROL_HOST || 'localhost',
  user: process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
  database: 'fincore_control'
});

async function check() {
  try {
    const tenants = await pool.query("SELECT pg_database, union_id, status FROM tenants");
    console.log('--- TENANTS ---');
    console.table(tenants.rows);

    for (const tenant of tenants.rows) {
      if (tenant.status === 'active') {
        const tPool = new Pool({
          host: process.env.PG_CONTROL_HOST || 'localhost',
          user: process.env.PG_CONTROL_USER || 'postgres',
          password: process.env.PG_CONTROL_PASSWORD,
          database: tenant.pg_database
        });
        try {
          const clients = await tPool.query("SELECT COUNT(*) FROM clients");
          console.log(`DB ${tenant.pg_database}: ${clients.rows[0].count} clients`);
        } catch (e) {
          console.error(`DB ${tenant.pg_database} ERROR:`, e.message);
        } finally {
          await tPool.end();
        }
      }
    }
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

check();
