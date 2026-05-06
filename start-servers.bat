@echo off
:: FinMob + AURUM — автозапуск всех сервисов
:: Этот скрипт запускается через Планировщик задач при входе пользователя

echo [%date% %time%] Task Scheduler triggered start-servers.bat >> "C:\Projects\FinMob\startup.log"

:: Запускаем основной скрипт в фоновом режиме
call "C:\Projects\FinMob\master-startup.bat" >> "C:\Projects\FinMob\startup.log" 2>&1

echo [%date% %time%] start-servers.bat completed. >> "C:\Projects\FinMob\startup.log"
