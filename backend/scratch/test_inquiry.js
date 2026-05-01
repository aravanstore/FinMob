const { Pool } = require('pg');
const p = new Pool({host:'localhost', port:5432, user:'postgres', password:'24994533', database:'boy'});

async function test() {
  try {
    console.log('Checking table...');
    await p.query(`
      CREATE TABLE IF NOT EXISTS client_inquiries (
        inquiry_id SERIAL PRIMARY KEY,
        client_id INTEGER,
        type TEXT DEFAULT 'GENERAL',
        message TEXT NOT NULL,
        status TEXT DEFAULT 'NEW',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    console.log('Inserting...');
    const res = await p.query(
      `INSERT INTO client_inquiries (client_id, type, message) VALUES ($1, $2, $3) RETURNING *`,
      [123, 'GENERAL', 'Test message from script']
    );
    console.log('Success:', res.rows[0]);
  } catch (e) {
    console.error('FAILED:', e);
  } finally {
    process.exit(0);
  }
}

test();
