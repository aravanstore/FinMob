-- Meridian Mobile: таблица доступа клиентов к мобильному приложению
-- Создаётся ОДИН РАЗ в каждой БД арендатора (aravan_1, aurum_db, ...)
-- Привязана к реальной таблице clients по client_id

CREATE TABLE IF NOT EXISTS mobile_client_access (
  access_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id   UUID NOT NULL,
  phone       VARCHAR(50) UNIQUE NOT NULL,  -- Логин клиента (теперь используется ИНН)
  pin_hash    TEXT NOT NULL,                 -- bcrypt hash
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMP DEFAULT NOW(),
  last_login  TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mobile_access_phone    ON mobile_client_access(phone);
CREATE INDEX IF NOT EXISTS idx_mobile_access_client   ON mobile_client_access(client_id);
CREATE INDEX IF NOT EXISTS idx_mobile_access_active   ON mobile_client_access(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE mobile_client_access IS
  'Доступ клиентов к мобильному приложению Meridian. '
  'phone = clients.phone_main, pin_hash = bcrypt(4-значный PIN). '
  'Создаётся сотрудником МФО при подключении клиента к приложению.';
