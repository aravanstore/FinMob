@echo off
title FinMob Auto-Startup
color 0B

echo ===================================================
echo     FinMob and AURUM Services Startup
echo ===================================================
echo.
echo [1/2] Starting all background services (Servers)...
:: Start/Restart all services defined in ecosystem
call "C:\Users\user\AppData\Roaming\npm\pm2.cmd" start C:\Projects\FinMob\ecosystem.config.js
call "C:\Users\user\AppData\Roaming\npm\pm2.cmd" save --force

echo.
echo [2/2] Launching Android Emulator (Pixel_8_Pro)...
:: Using start "" to run it asynchronously without blocking the script
start "" "C:\Users\user\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Pixel_8_Pro

echo.
echo ===================================================
echo     All tasks initiated! You can close this window.
echo ===================================================
timeout /t 5
