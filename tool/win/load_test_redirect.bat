@echo off
setlocal
if "%~1"=="" (
  echo Usage: tool\win\load_test_redirect.bat http://127.0.0.1:8080/Slug [requests] [concurrency] [max_p95_ms]
  exit /b 2
)
pushd "%~dp0..\.."
if errorlevel 1 exit /b 1
cargo run --quiet --manifest-path linkso_server\Cargo.toml --bin redirect_load -- "%~1" %2 %3 %4
set "command_result=%errorlevel%"
popd
exit /b %command_result%
