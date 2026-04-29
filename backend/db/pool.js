require('dotenv').config();
const { Pool } = require('pg');

// ─── Control Pool (fincore_control) ────────────────────────────────────────
// Читает таблицу tenants: union_id → pg_database
const controlPool = new Pool({
  host:     process.env.PG_CONTROL_HOST || 'localhost',
  port:     parseInt(process.env.PG_CONTROL_PORT || '5432'),
  database: process.env.PG_CONTROL_DB   || 'fincore_control',
  user:     process.env.PG_CONTROL_USER || 'postgres',
  password: process.env.PG_CONTROL_PASSWORD,
  max: 5,
});

controlPool.on('connect', () => console.log('[Control DB] connected'));
controlPool.on('error',   (e) => console.error('[Control DB] error:', e.message));

// ─── Tenant Pools Cache ─────────────────────────────────────────────────────
// Пул соединений на каждую БД арендатора (кэш, не пересоздаём)
const tenantPools = new Map();

function getTenantPool(dbName) {
  if (tenantPools.has(dbName)) return tenantPools.get(dbName);

  const pool = new Pool({
    host:     process.env.PG_CONTROL_HOST || 'localhost',
    port:     parseInt(process.env.PG_CONTROL_PORT || '5432'),
    user:     process.env.PG_CONTROL_USER || 'postgres',
    password: process.env.PG_CONTROL_PASSWORD,
    database: dbName,
    max: 10,
  });

  pool.on('error', (e) => console.error(`[Tenant DB: ${dbName}] error:`, e.message));
  tenantPools.set(dbName, pool);
  console.log(`[Tenant DB] Pool created for: ${dbName}`);
  return pool;
}

// ─── Lookup: union_id → pg_database ────────────────────────────────────────
async function getDbNameForUnion(unionId) {
  const { rows } = await controlPool.query(
    `SELECT pg_database FROM tenants
     WHERE union_id::text = $1 AND status = 'active'
     LIMIT 1`,
    [String(unionId)]
  );
  return rows[0]?.pg_database || null;
}

// ─── Lookup: pg_database → union_id ────────────────────────────────────────
async function getUnionIdForDb(dbName) {
  const { rows } = await controlPool.query(
    `SELECT union_id FROM tenants
     WHERE pg_database = $1 AND status = 'active'
     LIMIT 1`,
    [dbName]
  );
  return rows[0]?.union_id || null;
}

module.exports = { controlPool, getTenantPool, getDbNameForUnion, getUnionIdForDb };
