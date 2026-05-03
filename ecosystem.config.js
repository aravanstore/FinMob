module.exports = {
  apps: [
    {
      name: 'finmob-backend',
      script: 'index.js',                    // запускаем из cwd
      cwd: 'c:/Projects/FinMob/backend',     // рабочая папка = папка backend
      env: {
        NODE_ENV: 'production',
        PORT: '3002',
        // ── Все переменные из backend/.env явно ──────────────────────────
        PG_CONTROL_HOST:     'localhost',
        PG_CONTROL_PORT:     '5432',
        PG_CONTROL_DB:       'fincore_control',
        PG_CONTROL_USER:     'postgres',
        PG_CONTROL_PASSWORD: '24994533',   // строка, не число!
        JWT_SECRET:          'super_secret_key_change_this',
      },
      // Автоперезапуск при падении
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
    },
    {
      name: 'aurum-server',
      script: 'server.js',
      cwd: 'c:/AURUM',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
    },
    {
      name: 'aurum-ui',
      script: 'npx',
      args: 'vite --port 5173',
      cwd: 'c:/AURUM',
      autorestart: false,
    }
  ]
};
