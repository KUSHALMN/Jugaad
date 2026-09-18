@echo off
title Jugaad App Launcher
cls
echo ===================================================================
echo                     JUGAAD APP LAUNCHER
echo ===================================================================
echo.
echo  [1] Start Backend + Flutter Mobile App (Default)
echo  [2] Start Backend + Admin Web Dashboard (Vite)
echo  [3] Start Backend + BOTH (Mobile App + Admin Web)
echo  [4] Start in Separate Windows (Best for Flutter hot-reload 'r')
echo  [5] Start Backend API Only
echo.
echo ===================================================================

set /p choice="Select option [1-5] (Default: 1): "
if "%choice%"=="" set choice=1

if "%choice%"=="1" (
    echo.
    echo Starting Backend + Flutter Mobile...
    python run_all.py
    goto end
)
if "%choice%"=="2" (
    echo.
    echo Starting Backend + Admin Web Dashboard...
    python run_all.py --web
    goto end
)
if "%choice%"=="3" (
    echo.
    echo Starting Backend + Mobile + Admin Web...
    python run_all.py --all
    goto end
)
if "%choice%"=="4" (
    echo.
    echo Launching services in separate dedicated windows...
    python run_all.py -w
    goto end
)
if "%choice%"=="5" (
    echo.
    echo Starting Backend API Only...
    python run_all.py --backend-only
    goto end
)

echo Invalid choice. Starting default (Backend + Flutter Mobile)...
python run_all.py

:end
