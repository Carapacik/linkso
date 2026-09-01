@echo off
rem Stop containers without deleting containers or database volumes.
call "%~dp0_compose.bat" --profile app stop
exit /b %errorlevel%
