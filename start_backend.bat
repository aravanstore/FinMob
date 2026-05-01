@echo off
title FinMob Backend Server (Port 3002)
color 0A

echo ===================================================
echo     Starting Meridian Mobile API on port 3002
echo ===================================================

:: Переходим в папку проекта
cd /d "C:\Projects\FinMob\backend"

:: Запускаем сервер
npm run dev

pause
