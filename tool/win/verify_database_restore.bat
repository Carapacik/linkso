@echo off
setlocal EnableExtensions

if "%~1"=="" (
  echo Usage: tool\win\verify_database_restore.bat backup.dump
  exit /b 2
)
set "BACKUP_PATH=%~f1"
if not exist "%BACKUP_PATH%" (
  echo Backup file does not exist: %BACKUP_PATH%
  exit /b 2
)

echo ==^> Restoring into isolated database linkso_restore_test
for /f "usebackq delims=" %%I in (`call "%~dp0_compose.bat" exec -T postgres printenv POSTGRES_USER`) do set "database_user=%%I"
for /f "usebackq delims=" %%I in (`call "%~dp0_compose.bat" exec -T postgres printenv POSTGRES_DB`) do set "database_name=%%I"
if not defined database_user exit /b 1
if not defined database_name exit /b 1
call "%~dp0_compose.bat" exec -T postgres dropdb --if-exists -U "%database_user%" linkso_restore_test
if errorlevel 1 exit /b 1
call "%~dp0_compose.bat" exec -T postgres createdb -U "%database_user%" linkso_restore_test
if errorlevel 1 exit /b 1
call "%~dp0_compose.bat" exec -T postgres pg_restore -U "%database_user%" -d linkso_restore_test --no-owner --no-privileges < "%BACKUP_PATH%"
if errorlevel 1 goto :cleanup_failed
call "%~dp0_compose.bat" exec -T postgres psql -U "%database_user%" -d linkso_restore_test -Atc "SELECT current_database(), COUNT(*) FROM links GROUP BY current_database()"
if errorlevel 1 goto :cleanup_failed
for /f "usebackq delims=" %%I in (`call "%~dp0_compose.bat" exec -T postgres psql -U "%database_user%" -d "%database_name%" -Atc "SELECT COUNT(*) FROM _sqlx_migrations WHERE success"`) do set "SOURCE_MIGRATIONS=%%I"
for /f "usebackq delims=" %%I in (`call "%~dp0_compose.bat" exec -T postgres psql -U "%database_user%" -d linkso_restore_test -Atc "SELECT COUNT(*) FROM _sqlx_migrations WHERE success"`) do set "RESTORED_MIGRATIONS=%%I"
if not defined SOURCE_MIGRATIONS goto :cleanup_failed
if not "%SOURCE_MIGRATIONS%"=="%RESTORED_MIGRATIONS%" goto :cleanup_failed
call "%~dp0_compose.bat" exec -T postgres dropdb --if-exists -U "%database_user%" linkso_restore_test
if errorlevel 1 exit /b 1
echo Restore verification passed.
exit /b 0

:cleanup_failed
call "%~dp0_compose.bat" exec -T postgres dropdb --if-exists -U "%database_user%" linkso_restore_test
echo Restore verification failed.
exit /b 1
