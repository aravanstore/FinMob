const { Client } = require('pg');
async function run() {
  const c = new Client({ user: 'postgres', password: '24994533', database: 'boy' });
  await c.connect();
  const res = await c.query("SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'mobile_client_access' ORDER BY ordinal_position");
  console.log('Columns:', res.rows);
  await c.end();
}
run().catch(e => console.log('Error:', e.message));
