@echo off
setlocal
pushd "%~dp0..\.."
if errorlevel 1 exit /b 1
if not defined LINKSO_COMPOSE_FILE set "LINKSO_COMPOSE_FILE=docker-compose.yaml"
if defined LINKSO_ENV_FILE (
  docker compose --env-file "%LINKSO_ENV_FILE%" -f "%LINKSO_COMPOSE_FILE%" %*
) else (
  docker compose -f "%LINKSO_COMPOSE_FILE%" %*
)
set "command_result=%errorlevel%"
popd
exit /b %command_result%
