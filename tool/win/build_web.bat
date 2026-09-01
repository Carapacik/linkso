@echo off
setlocal
pushd "%~dp0..\..\linkso_client"
if errorlevel 1 exit /b 1
set "config_file=.env.example"
if exist .env set "config_file=.env"
call flutter build web --release --wasm --no-web-resources-cdn --dart-define-from-file="%config_file%" %*
set "command_result=%errorlevel%"
popd
exit /b %command_result%
