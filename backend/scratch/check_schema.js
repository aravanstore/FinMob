const { Pool } = require('pg');
require('dotenv').config();

async function check() {
  const pool = new Pool({
    host: 'localhost',
    user: process.env.PG_CONTROL_USER,
    password: process.env.PG_CONTROL_PASSWORD,
    database: 'aravan_bbd'
  });

  try {
    const res = await pool.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'internal_chat_messages'");
    console.log(res.rows);
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}

check();
