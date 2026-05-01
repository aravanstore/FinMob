require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  const fs = require('fs');
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const msg = `[${new Date().toISOString()}] ${req.method} ${req.url} ${res.statusCode} (${duration}ms)\n`;
    fs.appendFileSync('requests.log', msg);
    console.log(msg);
  });
  next();
});

// ─── Роуты ─────────────────────────────────────────────────────────────────
app.use('/api/auth',     require('./routes/auth'));
app.use('/api/loans',    require('./routes/loans'));
app.use('/api/shares',   require('./routes/shares'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/inquiries', require('./routes/inquiries'));
app.use('/api/announcements', require('./routes/announcements'));

// Сотрудники: ТОЛЬКО ЧТЕНИЕ (read-only)
// Правило безопасности: мобильный может попасть в чужие руки.
// Никаких мутаций данных — только просмотр клиентов, кредитов, просрочки.
app.use('/api/staff',    require('./routes/staff'));

// ─── Health check ───────────────────────────────────────────────────────────
app.get('/health', (req, res) =>
  res.json({ status: 'ok', service: 'Meridian Mobile API', time: new Date() })
);

// ─── 404 ────────────────────────────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ error: 'Маршрут не найден' }));

// ─── Global error handler ───────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('[Unhandled Error]', err);
  res.status(500).json({ error: 'Внутренняя ошибка сервера' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`\n🚀 Meridian Mobile API → http://localhost:${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/health\n`);
});
