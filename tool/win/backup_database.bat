@echo off
setlocal EnableExtensions

set "BACKUP_DIR=%LINKSO_BACKUP_DIR%"
if not "%~1"=="" set "BACKUP_DIR=%~f1"
if not defined BACKUP_DIR (
  echo Usage: tool\win\backup_database.bat absolute-output-directory
  echo Or set LINKSO_BACKUP_DIR. Store backups outside the repository.
  exit /b 2
)
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if errorlevel 1 exit /b 1
for /f %%I in ('powershell -NoProfile -Command "[DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')"') do set "STAMP=%%I"
set "BACKUP_PATH=%BACKUP_DIR%\linkso_%STAMP%.dump"

echo ==^> Creating local PostgreSQL backup %BACKUP_PATH%
for /f "usebackq delims=" %%I in (`call "%~dp0_compose.bat" exec -T postgres printenv POSTGRES_USER`) do set "database_user=%%I"
for /f "usebackq delims=" %%I in (`call "%~dp0_compose.bat" exec -T postgres printenv POSTGRES_DB`) do set "database_name=%%I"
if not defined database_user exit /b 1
if not defined database_name exit /b 1
call "%~dp0_compose.bat" exec -T postgres pg_dump -U "%database_user%" -d "%database_name%" -Fc > "%BACKUP_PATH%"
if errorlevel 1 (
  del /q "%BACKUP_PATH%" 2^>nul
  echo Backup failed.
  exit /b 1
)
for %%I in ("%BACKUP_PATH%") do if %%~zI LSS 64 (
  echo Backup is unexpectedly small.
  del /q "%BACKUP_PATH%"
  exit /b 1
)
echo Backup created: %BACKUP_PATH%
