const bcrypt = require('bcrypt');
const { Client } = require('pg');

async function seed() {
  const c = new Client({ user: 'postgres', password: '24994533', database: 'boy' });
  await c.connect();
  const pinHash = await bcrypt.hash('1234', 10);
  
  // check if exists
  const res = await c.query('SELECT access_id FROM mobile_client_access WHERE phone = $1', ['996559334033']);
  if (res.rows.length === 0) {
    await c.query('INSERT INTO mobile_client_access (client_id, phone, pin_hash) VALUES ($1, $2, $3)', ['1a2279db-87d6-4478-a58c-a39e0f45fa23', '996559334033', pinHash]);
    console.log('Created borrower login');
  } else {
    await c.query('UPDATE mobile_client_access SET pin_hash = $2 WHERE phone = $1', ['996559334033', pinHash]);
    console.log('Updated borrower login');
  }
  await c.end();
}

seed().catch(e => console.log('Error:', e.message));
