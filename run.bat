@echo off
title Jugaad App Launcher
cls

:: If arguments were passed directly to run.bat, execute immediately without prompting
if not "%~1"=="" (
    python "%~dp0run_all.py" %*
    goto end
)

echo ===================================================================
echo                     JUGAAD APP LAUNCHER
echo ===================================================================
echo.
echo  [1] Start Backend + Flutter Mobile App (Default - Just press Enter)
echo  [2] Start Backend + Admin Web Dashboard (Vite)
echo  [3] Start Backend + BOTH (Mobile App + Admin Web)
echo  [4] Start Backend + Flutter Mobile on Android device/emulator
echo  [5] Start Backend API Only
echo.
echo ===================================================================

set choice=1
set /p choice="Select option [1-5] (Default: 1): "

if "%choice%"=="1" (
    echo.
    echo Starting Backend + Flutter Mobile App...
    python "%~dp0run_all.py"
    goto end
)
if "%choice%"=="2" (
    echo.
    echo Starting Backend + Admin Web Dashboard...
    python "%~dp0run_all.py" --web
    goto end
)
if "%choice%"=="3" (
    echo.
    echo Starting Backend + Mobile + Admin Web...
    python "%~dp0run_all.py" --all
    goto end
)
if "%choice%"=="4" (
    echo.
    echo Starting Backend + Flutter Mobile on Android...
    python "%~dp0run_all.py" -d android
    goto end
)
if "%choice%"=="5" (
    echo.
    echo Starting Backend API Only...
    python "%~dp0run_all.py" --backend-only
    goto end
)

echo.
echo Starting default (Backend + Flutter Mobile)...
python "%~dp0run_all.py"

:end
