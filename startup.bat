@echo off
title FinMob & AURUM Master Startup
color 0B

echo ===================================================
echo     FinMob and AURUM Services Startup
echo ===================================================
echo [%date% %time%] Startup initiated... >> "C:\Projects\FinMob\startup.log"

:: 1. Start PM2 services
echo [1/2] Starting backend services via PM2...
call "C:\Users\user\AppData\Roaming\npm\pm2.cmd" start C:\Projects\FinMob\ecosystem.config.js >> "C:\Projects\FinMob\startup.log" 2>&1

:: 2. Launch Android Emulator
echo [2/2] Launching Android Emulator (Pixel_8_Pro)...
start "" "C:\Users\user\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Pixel_8_Pro

echo.
echo ===================================================
echo     Startup sequence completed!
echo ===================================================
echo [%date% %time%] Startup sequence finished. >> "C:\Projects\FinMob\startup.log"
timeout /t 5
