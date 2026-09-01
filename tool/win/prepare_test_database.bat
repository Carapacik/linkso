@echo off
setlocal

set "test_database=linkso_test"

pushd "%~dp0..\.."
if errorlevel 1 exit /b %errorlevel%

echo ==^> Starting PostgreSQL
call docker compose up -d --wait postgres
if errorlevel 1 goto :failed

for /f "usebackq delims=" %%i in (`docker compose exec -T postgres printenv POSTGRES_USER`) do set "database_user=%%i"
if not defined database_user (
  echo Failed to read POSTGRES_USER from the PostgreSQL container. 1>&2
  goto :failed
)

echo ==^> Preparing test database %test_database%
call docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -v "test_database=%test_database%" -v "database_user=%database_user%" -U "%database_user%" -d postgres < "%~dp0..\sql\prepare_test_database.sql"
if errorlevel 1 goto :failed

call docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "%database_user%" -d "%test_database%" -c "SELECT current_database(), current_user;"
if errorlevel 1 goto :failed

if not exist "%~dp0..\..\linkso_server\.env.test" (
  copy /y "%~dp0..\..\linkso_server\.env.test.example" "%~dp0..\..\linkso_server\.env.test" >nul
  if errorlevel 1 goto :failed
)

popd
echo Test database %test_database% is ready.
exit /b 0

:failed
set "prepare_exit_code=%errorlevel%"
if "%prepare_exit_code%"=="0" set "prepare_exit_code=1"
popd
exit /b %prepare_exit_code%
