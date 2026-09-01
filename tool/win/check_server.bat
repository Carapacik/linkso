@echo off
setlocal

pushd "%~dp0..\..\linkso_server"
if errorlevel 1 exit /b %errorlevel%

echo ==^> Cargo format check
call cargo fmt --check
if errorlevel 1 goto :failed

echo ==^> Cargo clippy
call cargo clippy --all-targets --all-features -- -D warnings
if errorlevel 1 goto :failed

echo ==^> Cargo tests
call cargo test
if errorlevel 1 goto :failed

popd
echo Server checks passed.
exit /b 0

:failed
popd
exit /b 1
