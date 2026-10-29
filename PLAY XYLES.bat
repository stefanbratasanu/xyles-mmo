@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev\launch_xyles.ps1"
if errorlevel 1 (
    echo.
    echo Game launch stopped. Please keep this window open to read the message above.
    pause
)
