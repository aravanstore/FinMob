const router = require('express').Router();
const auth = require('../middleware/auth');
const { getTenantPool } = require('../db/pool');

const getPool = (req) => getTenantPool(req.client.dbName);

// ─────────────────────────────────────────────────────────────────────────────
// Чат Клиент <-> Офис/Сотрудники
// ─────────────────────────────────────────────────────────────────────────────

router.get('/contacts', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const clientId = req.client.clientId;

    const sql = `
      WITH contacts AS (
        SELECT 
          user_id::text as contact_id,
          full_name as contact_name,
          NULL as contact_phone,
          role as contact_type,
          'STAFF' as entity_type
        FROM users
        WHERE is_active = true
      ),
      chat_summary AS (
        SELECT 
          c.contact_id,
          c.contact_name,
          c.contact_phone,
          c.contact_type,
          c.entity_type,
          (
            SELECT message_text 
            FROM internal_chat_messages 
            WHERE 
               -- Ищем личные сообщения (учитывая что из офиса они могут писать как 'OFFICE')
               (sender_id = c.contact_id AND receiver_id = $1) OR (sender_id = $1 AND receiver_id = c.contact_id)
            ORDER BY created_at DESC 
            LIMIT 1
          ) as last_message,
          (
            SELECT created_at 
            FROM internal_chat_messages 
            WHERE 
               (sender_id = c.contact_id AND receiver_id = $1) OR (sender_id = $1 AND receiver_id = c.contact_id)
            ORDER BY created_at DESC 
            LIMIT 1
          ) as last_message_date,
          (
            SELECT COUNT(*) 
            FROM internal_chat_messages 
            WHERE is_read = false AND sender_id = c.contact_id AND receiver_id = $1
          ) as unread_count
        FROM contacts c
      )
      SELECT * FROM chat_summary
      ORDER BY last_message_date DESC NULLS LAST, contact_name ASC
    `;
    
    const { rows } = await pool.query(sql, [String(clientId)]);
    res.json(rows);
  } catch (err) {
    console.error('GET /api/chat/contacts', err);
    res.status(500).json({ error: 'Ошибка получения контактов' });
  }
});

router.get('/history', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const clientId = req.client.clientId;
    const { receiverId, receiverType } = req.query;
    
    if (!receiverId || !receiverType) {
        return res.status(400).json({ error: 'receiverId and receiverType required' });
    }

    // Mark as read
    await pool.query(`
      UPDATE internal_chat_messages 
      SET is_read = true 
      WHERE receiver_id = $1 AND sender_id = $2
    `, [String(clientId), receiverId]);

    const query = `
      SELECT * FROM internal_chat_messages
      WHERE 
         -- Все сообщения между этим клиентом и этим ID сотрудника (независимо от STAFF/OFFICE/CLIENT)
         (sender_id = $1 AND receiver_id = $2)
         OR (sender_id = $2 AND receiver_id = $1)
         -- А также сообщения от него, если он писал как OFFICE
         OR (sender_type = 'OFFICE' AND sender_id = $2 AND receiver_id = $1)
         OR (receiver_type = 'OFFICE' AND receiver_id = $2 AND sender_id = $1)
      ORDER BY created_at ASC
      LIMIT 200
    `;
    const { rows } = await pool.query(query, [String(clientId), receiverId]);
    res.json(rows);
  } catch (err) {
    console.error('GET /api/chat/history', err);
    res.status(500).json({ error: 'Ошибка получения истории чата' });
  }
});

router.post('/send', auth, async (req, res) => {
  try {
    const pool = getPool(req);
    const clientId = req.client.clientId;
    const { messageText, receiverId, receiverType } = req.body;
    
    if (!messageText || !receiverId || !receiverType) {
      return res.status(400).json({ error: 'messageText, receiverId, receiverType обязательны' });
    }

    const query = `
      INSERT INTO internal_chat_messages (sender_type, sender_id, receiver_type, receiver_id, message_text)
      VALUES ('CLIENT', $1, $2, $3, $4)
      RETURNING *
    `;
    const { rows } = await pool.query(query, [String(clientId), receiverType, receiverId, messageText]);
    
    res.json({ success: true, message: rows[0] });
  } catch (err) {
    console.error('POST /api/chat/send', err);
    res.status(500).json({ error: 'Ошибка отправки сообщения' });
  }
});

module.exports = router;
