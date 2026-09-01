@echo off
setlocal

call "%~dp0prepare_test_database.bat"
if errorlevel 1 exit /b %errorlevel%

pushd "%~dp0..\..\linkso_server"
if errorlevel 1 exit /b %errorlevel%

echo ==^> Database integration tests
call cargo test --test database_health -- --ignored --test-threads=1
if errorlevel 1 goto :failed

popd
echo Server integration tests passed.
exit /b 0

:failed
set "test_exit_code=%errorlevel%"
popd
exit /b %test_exit_code%
