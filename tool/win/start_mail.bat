@echo off
call "%~dp0_compose.bat" --profile mail up --detach --wait mailpit
exit /b %errorlevel%
