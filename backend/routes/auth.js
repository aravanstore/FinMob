const router  = require('express').Router();
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const { controlPool, getTenantPool } = require('../db/pool');

// ─── КЛИЕНТ: POST /api/auth/login ──────────────────────────────────────────
router.post('/login', async (req, res) => {
  const { pg_database, phone, pin } = req.body;

  if (!pg_database || !phone || !pin) {
    return res.status(400).json({ error: 'Необходимы: pg_database, phone, pin' });
  }

  try {
    const { rows: tenantRows } = await controlPool.query(
      `SELECT tenant_id, union_id, pg_database, name
       FROM tenants WHERE pg_database = $1 AND status = 'active' LIMIT 1`,
      [pg_database]
    );
    if (!tenantRows.length) {
      return res.status(404).json({ error: 'Организация не найдена или неактивна' });
    }

    const tenant = tenantRows[0];
    const pool   = getTenantPool(tenant.pg_database);

    const { rows: accessRows } = await pool.query(
      `SELECT mca.access_id, mca.client_id, mca.pin_hash, mca.is_active,
              c.full_name, c.phone_main, c.status AS client_status
       FROM mobile_client_access mca
       JOIN clients c ON c.client_id = mca.client_id
       WHERE mca.phone = $1 LIMIT 1`,
      [phone]
    );
    if (!accessRows.length) return res.status(404).json({ error: 'Клиент не найден' });

    const access = accessRows[0];
    if (!access.is_active) return res.status(403).json({ error: 'Доступ заблокирован' });

    const validPin = await bcrypt.compare(String(pin), access.pin_hash);
    if (!validPin) return res.status(401).json({ error: 'Неверный PIN' });

    await pool.query(
      'UPDATE mobile_client_access SET last_login = NOW() WHERE access_id = $1',
      [access.access_id]
    );

    const token = jwt.sign(
      {
        role:       'client',
        clientId:   access.client_id,
        phone:      access.phone_main,
        fullName:   access.full_name,
        unionId:    tenant.union_id,
        dbName:     tenant.pg_database,
        tenantName: tenant.name,
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      token,
      role: 'client',
      client: {
        clientId:   access.client_id,
        fullName:   access.full_name,
        phone:      access.phone_main,
        tenantName: tenant.name,
      },
    });
  } catch (err) {
    console.error('[POST /api/auth/login]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ─── СОТРУДНИК: POST /api/auth/staff-login ─────────────────────────────────
// Использует таблицу users в БД арендатора (существующие логины AURUM)
router.post('/staff-login', async (req, res) => {
  const { pg_database, username, password } = req.body;

  if (!pg_database || !username || !password) {
    return res.status(400).json({ error: 'Необходимы: pg_database, username, password' });
  }

  try {
    const { rows: tenantRows } = await controlPool.query(
      `SELECT tenant_id, union_id, pg_database, name
       FROM tenants WHERE pg_database = $1 AND status = 'active' LIMIT 1`,
      [pg_database]
    );
    if (!tenantRows.length) {
      return res.status(404).json({ error: 'Организация не найдена или неактивна' });
    }

    const tenant = tenantRows[0];
    const pool   = getTenantPool(tenant.pg_database);

    // Ищем в таблице users (стандартная таблица AURUM)
    const { rows: userRows } = await pool.query(
      `SELECT user_id, username, password_hash, full_name, role, is_active, permissions
       FROM users
       WHERE username = $1 LIMIT 1`,
      [username]
    );

    if (!userRows.length) return res.status(404).json({ error: 'Пользователь не найден' });

    const user = userRows[0];
    if (!user.is_active) return res.status(403).json({ error: 'Аккаунт деактивирован' });

    const validPwd = await bcrypt.compare(password, user.password_hash);
    if (!validPwd) return res.status(401).json({ error: 'Неверный пароль' });

    // Обновляем last_login
    await pool.query(
      'UPDATE users SET last_login = NOW() WHERE user_id = $1',
      [user.user_id]
    );

    const token = jwt.sign(
      {
        role:        'staff',
        userId:      user.user_id,
        clientId:    user.user_id, // Для системы уведомлений
        username:    user.username,
        fullName:    user.full_name,
        staffRole:   user.role,       // Admin / Operator / Manager / Chairman
        permissions: user.permissions,
        unionId:     tenant.union_id,
        dbName:      tenant.pg_database,
        tenantName:  tenant.name,
      },
      process.env.JWT_SECRET,
      { expiresIn: '24h' } // сотрудники — 24 часа
    );

    res.json({
      token,
      role: 'staff',
      user: {
        userId:     user.user_id,
        username:   user.username,
        fullName:   user.full_name,
        staffRole:  user.role,
        tenantName: tenant.name,
      },
    });
  } catch (err) {
    console.error('[POST /api/auth/staff-login]', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

module.exports = router;
