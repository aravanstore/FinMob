@echo off
:: FinMob + AURUM — автозапуск всех сервисов через PM2
:: Этот скрипт запускается через Планировщик задач при входе пользователя

echo [%date% %time%] Starting PM2 services... >> "C:\Projects\FinMob\startup.log"

:: Даём системе прогрузиться (PostgreSQL, сеть)
timeout /t 10 /nobreak > nul

:: Запускаем все процессы из сохранённого дампа PM2
call "C:\Users\user\AppData\Roaming\npm\pm2.cmd" resurrect >> "C:\Projects\FinMob\startup.log" 2>&1

echo [%date% %time%] PM2 resurrect done. >> "C:\Projects\FinMob\startup.log"
