docker run --name nginx -p 8080:8080 -d nginxdocker

start "linkso1" /d ..\ServerDotnet\WebApi\ dotnet run --no-build --urls http://*:5001
start "linkso2" /d ..\ServerDotnet\WebApi\ dotnet run --no-build --urls http://*:5002

