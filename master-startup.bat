@echo off
title FinMob & AURUM Master Startup
color 0B

echo ===================================================
echo     FinMob and AURUM Services Startup (Robust)
echo ===================================================
echo [%date% %time%] Startup initiated... >> "C:\Projects\FinMob\startup.log"

:: 1. Attempt to start via PM2 (Standard way)
echo [1/3] Trying PM2 startup...
call "C:\Users\user\AppData\Roaming\npm\pm2.cmd" start C:\Projects\FinMob\ecosystem.config.js >> "C:\Projects\FinMob\startup.log" 2>&1

:: Check if PM2 failed (EPERM error usually results in no processes)
:: We will check if the processes are actually running after 5 seconds
timeout /t 5 /nobreak > nul

:: 2. Fallback: Direct Node.js startup if PM2 is stuck
echo [2/3] Checking if services are online...
netstat -ano | findstr :3002 > nul
if %errorlevel% neq 0 (
    echo [!] FinMob Backend (3002) not detected. Starting directly...
    echo [%date% %time%] PM2 failed. Starting FinMob Backend directly. >> "C:\Projects\FinMob\startup.log"
    start /B "FinMob-Backend" cmd /c "cd /d C:\Projects\FinMob\backend && node index.js >> C:\Projects\FinMob\backend.log 2>&1"
) else (
    echo [OK] FinMob Backend is running.
)

netstat -ano | findstr :3001 > nul
if %errorlevel% neq 0 (
    echo [!] AURUM Server (3001) not detected. Starting directly...
    echo [%date% %time%] PM2 failed. Starting AURUM Server directly. >> "C:\Projects\FinMob\startup.log"
    start /B "AURUM-Server" cmd /c "cd /d C:\AURUM && node server.js >> C:\AURUM\server.log 2>&1"
) else (
    echo [OK] AURUM Server is running.
)

:: 3. Launch Android Emulator
echo [3/3] Launching Android Emulator (Pixel_8_Pro)...
start "" "C:\Users\user\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Pixel_8_Pro

echo.
echo ===================================================
echo     Startup sequence completed!
echo ===================================================
echo [%date% %time%] Startup sequence finished. >> "C:\Projects\FinMob\startup.log"
timeout /t 5
