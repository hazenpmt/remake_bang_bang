@echo off
setlocal
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 "%~dp0asset_duplicate_guard.py" scan
) else (
  python "%~dp0asset_duplicate_guard.py" scan
)
exit /b %errorlevel%
