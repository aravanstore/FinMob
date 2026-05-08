const { controlPool, getTenantPool } = require('../db/pool');

async function checkTokens() {
  try {
    const { rows: tenants } = await controlPool.query("SELECT name, pg_database FROM tenants WHERE status = 'active'");
    console.log(`Found ${tenants.length} active tenants.\n`);

    for (const tenant of tenants) {
      const pool = getTenantPool(tenant.pg_database);
      try {
        const { rows: tokens } = await pool.query("SELECT COUNT(*) as count FROM fcm_tokens");
        const { rows: latest } = await pool.query("SELECT client_id, updated_at FROM fcm_tokens ORDER BY updated_at DESC LIMIT 1");
        
        console.log(`Tenant: ${tenant.name} (${tenant.pg_database})`);
        console.log(`  Total Tokens: ${tokens[0].count}`);
        if (latest.length > 0) {
          console.log(`  Latest Registration: Client ${latest[0].client_id} at ${latest[0].updated_at}`);
        } else {
          console.log(`  No tokens found.`);
        }
      } catch (err) {
        if (err.message.includes('relation "fcm_tokens" does not exist')) {
          console.log(`  Tenant: ${tenant.name} - Table fcm_tokens NOT CREATED YET.`);
        } else {
          console.log(`  Tenant: ${tenant.name} - Error: ${err.message}`);
        }
      }
    }
    process.exit(0);
  } catch (err) {
    console.error('Fatal Error:', err);
    process.exit(1);
  }
}

checkTokens();
