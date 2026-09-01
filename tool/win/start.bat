@echo off
call "%~dp0_compose.bat" --profile app up --detach --build --wait
exit /b %errorlevel%
