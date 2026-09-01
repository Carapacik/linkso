@echo off
rem Apply embedded migrations using the selected Compose configuration.
call "%~dp0_compose.bat" up --detach --wait postgres
if errorlevel 1 exit /b %errorlevel%
call "%~dp0_compose.bat" --profile app run --rm --no-deps --build server migrate
exit /b %errorlevel%
