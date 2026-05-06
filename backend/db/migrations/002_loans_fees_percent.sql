-- Migration 002: Add fees_percent column to loans table
-- Run on each tenant DB: psql -U postgres -d <tenant_db> -f backend/db/migrations/002_loans_fees_percent.sql

ALTER TABLE loans ADD COLUMN IF NOT EXISTS fees_percent NUMERIC DEFAULT 0;
