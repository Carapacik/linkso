@echo off
setlocal

pushd "%~dp0..\..\linkso_client"
if errorlevel 1 exit /b %errorlevel%

echo ==^> Dart format check
set "format_paths=lib"
if exist test set "format_paths=lib test"
call dart format --output=none --set-exit-if-changed %format_paths%
if errorlevel 1 goto :failed

echo ==^> Flutter analyze
call flutter analyze
if errorlevel 1 goto :failed

echo ==^> Flutter tests
dir /b /s "test\*_test.dart" >nul 2>&1
if not errorlevel 1 (
    call flutter test
    if errorlevel 1 goto :failed
) else (
    echo Skipped: no Flutter tests yet.
)

popd
echo Client checks passed.
exit /b 0

:failed
popd
exit /b 1
