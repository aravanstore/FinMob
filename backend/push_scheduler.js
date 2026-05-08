// ─────────────────────────────────────────────────────────────────────────────
// push_scheduler.js — cron задача для отправки уведомлений о платежах
//
// Запускать в index.js ОДНОЙ строкой:
//   require('./push_scheduler');
//
// Как работает:
//   - Каждый день в 09:00 утра проверяет займы по ВСЕМ tenant БД
//   - Находит займы у которых платёж через 3 дня или сегодня
//   - Отправляет push-уведомление на все устройства клиента
// ─────────────────────────────────────────────────────────────────────────────
const admin        = require('firebase-admin');
const { controlPool, getTenantPool } = require('./db/pool');

// ─── Инициализация Firebase Admin SDK ────────────────────────────────────────
// ВАЖНО: файл serviceAccountKey.json скачать из Firebase Console
//        Project Settings → Service accounts → Generate new private key
if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('[FCM] Firebase Admin SDK инициализирован');
}

// ─── Отправка одного уведомления ─────────────────────────────────────────────
async function sendPush(token, title, body, data = {}) {
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'payment_reminders',
        },
      },
    });
    return true;
  } catch (err) {
    // Токен устарел или недействителен — вернём false чтобы удалить его
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token'
    ) {
      return 'invalid';
    }
    console.error('[FCM] Ошибка отправки:', err.message);
    return false;
  }
}

// ─── Основная функция: проверяем платежи и шлём уведомления ─────────────────
async function runPaymentNotifications() {
  console.log('[FCM Scheduler] Запуск проверки платежей...');

  try {
    // Берём все активные tenant БД
    const { rows: tenants } = await controlPool.query(`
      SELECT pg_database, name FROM tenants WHERE status = 'active'
    `);

    for (const tenant of tenants) {
      await processTenant(tenant.pg_database, tenant.name);
    }

    console.log('[FCM Scheduler] Проверка завершена.');
  } catch (err) {
    console.error('[FCM Scheduler] Ошибка:', err.message);
  }
}

async function processTenant(dbName, tenantName) {
  const pool = getTenantPool(dbName);

  try {
    // Проверяем есть ли таблица fcm_tokens (могут не использовать уведомления)
    const { rows: tableCheck } = await pool.query(`
      SELECT 1 FROM information_schema.tables 
      WHERE table_name = 'fcm_tokens' LIMIT 1
    `);
    if (!tableCheck.length) return;

    // Ищем займы с платежом через 3 дня или сегодня
    // Используем next_payment_date если есть, иначе считаем по end_date
    const { rows: upcomingPayments } = await pool.query(`
      SELECT DISTINCT
        l.client_id,
        l.contract_number,
        l.next_payment_date,
        CASE 
          WHEN l.next_payment_date = CURRENT_DATE THEN 'today'
          WHEN l.next_payment_date = CURRENT_DATE + INTERVAL '3 days' THEN '3days'
          WHEN l.next_payment_date = CURRENT_DATE + INTERVAL '1 day' THEN '1day'
        END AS reminder_type
      FROM loans l
      WHERE l.status NOT IN ('Погашен', 'Закрыт', 'Отказан')
        AND (l.is_deleted = FALSE OR l.is_deleted IS NULL)
        AND l.next_payment_date IN (
          CURRENT_DATE,
          CURRENT_DATE + INTERVAL '1 day',
          CURRENT_DATE + INTERVAL '3 days'
        )
    `);

    console.log(`[FCM] ${dbName}: найдено ${upcomingPayments.length} уведомлений`);

    for (const payment of upcomingPayments) {
      // Получаем все FCM токены этого клиента
      const { rows: tokenRows } = await pool.query(
        `SELECT token_id, fcm_token FROM fcm_tokens WHERE client_id = $1`,
        [String(payment.client_id)]
      );
      if (!tokenRows.length) continue;

      let title, body;
      if (payment.reminder_type === 'today') {
        title = '💳 Платёж сегодня!';
        body  = `По договору ${payment.contract_number}. Оплатите до конца дня.`;
      } else if (payment.reminder_type === '1day') {
        title = '⏰ Платёж завтра';
        body  = `По договору ${payment.contract_number}. Не забудьте оплатить.`;
      } else {
        title = '📅 Напоминание о платеже';
        body  = `Через 3 дня платёж по договору ${payment.contract_number}.`;
      }

      // Отправляем на каждое устройство клиента
      for (const { token_id, fcm_token } of tokenRows) {
        const result = await sendPush(fcm_token, title, body, {
          type: 'payment_reminder',
          contract_number: payment.contract_number || '',
          reminder_type: payment.reminder_type || '',
        });

        // Если токен недействителен — удаляем его из БД
        if (result === 'invalid') {
          await pool.query(`DELETE FROM fcm_tokens WHERE token_id = $1`, [token_id]);
          console.log(`[FCM] Удалён устаревший токен ${token_id} (${dbName})`);
        }
      }
    }
  } catch (err) {
    console.error(`[FCM] Ошибка обработки ${dbName}:`, err.message);
  }
}

// ─── Планировщик: каждый день в 09:00 ────────────────────────────────────────
function scheduleDaily(hour, minute, fn) {
  function getNextRunMs() {
    const now  = new Date();
    const next = new Date();
    next.setHours(hour, minute, 0, 0);
    if (next <= now) next.setDate(next.getDate() + 1);
    return next - now;
  }

  function schedule() {
    const delay = getNextRunMs();
    const nextRun = new Date(Date.now() + delay);
    console.log(`[FCM Scheduler] Следующий запуск: ${nextRun.toLocaleString('ru')}`);
    setTimeout(() => {
      fn();
      schedule(); // планируем следующий запуск
    }, delay);
  }

  schedule();
}

// Запускаем каждый день в 09:00
scheduleDaily(9, 0, runPaymentNotifications);

// Экспортируем для ручного запуска (тест через /api/notifications/test-send)
module.exports = { runPaymentNotifications, sendPush };
