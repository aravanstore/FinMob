const bcrypt = require('bcrypt');
const { Client } = require('pg');

async function run() {
  const c = new Client({ user: 'postgres', password: '24994533', database: 'boy' });
  await c.connect();
  const res = await c.query('SELECT client_id, full_name, inn FROM clients WHERE inn = $1 LIMIT 1', ['23008197600853']);
  if (res.rows.length === 0) {
    console.log('Client not found!');
  } else {
    const client = res.rows[0];
    const pinHash = await bcrypt.hash('24994533', 10);
    const check = await c.query('SELECT access_id FROM mobile_client_access WHERE phone = $1', [client.inn]);
    if (check.rows.length === 0) {
      await c.query('INSERT INTO mobile_client_access (client_id, phone, pin_hash) VALUES ($1, $2, $3)', [client.client_id, client.inn, pinHash]);
      console.log('Created access for', client.full_name);
    } else {
      await c.query('UPDATE mobile_client_access SET pin_hash = $2, client_id = $1 WHERE phone = $3', [client.client_id, pinHash, client.inn]);
      console.log('Updated access for', client.full_name);
    }
  }
  await c.end();
}

run().catch(e => console.log('Error:', e.message));
