@echo off
setlocal
pushd "%~dp0..\.."
if errorlevel 1 exit /b 1
call node tool\brand\generate.cjs %*
if errorlevel 1 goto :failed
call dart format linkso_client\lib\src\core\widgets\linkso_logo_paths.g.dart
if errorlevel 1 goto :failed
popd
exit /b 0
:failed
popd
exit /b 1
