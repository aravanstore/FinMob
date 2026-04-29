-- Run once: psql -U postgres -d meridian -f backend/db/migrations/001_client_access.sql
 
CREATE TABLE IF NOT EXISTS client_access (
  id          SERIAL PRIMARY KEY,
  client_id   VARCHAR(50) UNIQUE NOT NULL,
  phone       VARCHAR(20) UNIQUE NOT NULL,
  pin_hash    TEXT NOT NULL,
  created_at  TIMESTAMP DEFAULT NOW(),
  last_login  TIMESTAMP
);
 
CREATE INDEX IF NOT EXISTS idx_client_access_phone ON client_access(phone);
