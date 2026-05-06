-- ============================================================
-- МИГРАЦИЯ: Исправление ANR + UUID в client_inquiries
-- Запускать вручную на каждой БД арендатора (tenant)
-- ============================================================

-- 1. Исправляем тип client_id в client_inquiries (UUID → TEXT)
--    Именно это вызывало ошибку: "неверный синтаксис для типа integer"
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'client_inquiries'
  ) THEN
    IF (
      SELECT data_type FROM information_schema.columns 
      WHERE table_name = 'client_inquiries' AND column_name = 'client_id'
    ) = 'integer' THEN
      RAISE NOTICE 'Меняем client_id с INTEGER на TEXT...';
      ALTER TABLE client_inquiries ALTER COLUMN client_id TYPE TEXT USING client_id::text;
      RAISE NOTICE 'Готово.';
    ELSE
      RAISE NOTICE 'client_id уже TEXT — ничего не нужно менять.';
    END IF;
  END IF;
END $$;

-- 2. Добавляем колонки если их нет
ALTER TABLE client_inquiries ADD COLUMN IF NOT EXISTS reply_message TEXT;
ALTER TABLE client_inquiries ADD COLUMN IF NOT EXISTS replied_at TIMESTAMP;

-- 3. Индексы для ускорения поиска клиентов (исправление ANR на экране "Выбор клиента")
--    Без этого индекса ORDER BY created_at делает seq scan по всей таблице
CREATE INDEX IF NOT EXISTS idx_clients_created_at 
  ON clients(created_at DESC) 
  WHERE (is_deleted = FALSE OR is_deleted IS NULL);

CREATE INDEX IF NOT EXISTS idx_clients_fio_bindex 
  ON clients(fio_bindex) 
  WHERE (is_deleted = FALSE OR is_deleted IS NULL);

CREATE INDEX IF NOT EXISTS idx_clients_inn_bindex 
  ON clients(inn_bindex) 
  WHERE (is_deleted = FALSE OR is_deleted IS NULL);

CREATE INDEX IF NOT EXISTS idx_clients_phone_main 
  ON clients(phone_main) 
  WHERE (is_deleted = FALSE OR is_deleted IS NULL);

-- 4. Индекс для inquiries (поиск обращений клиента)
CREATE INDEX IF NOT EXISTS idx_client_inquiries_client_id 
  ON client_inquiries(client_id);

RAISE NOTICE '✅ Миграция 003 завершена успешно.';
