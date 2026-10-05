@echo off
cd /d "%~dp0"
echo === THIET LAP DATABASE BANGBANG ===
echo Mat khau postgres se duoc an khi nhap.
cmd /c npm run setup-db
echo.
pause
