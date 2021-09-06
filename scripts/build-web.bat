CALL cd ..
CALL .flutter\bin\flutter.bat doctor
CALL cd ClientFlutter
CALL ..\.flutter\bin\flutter.bat clean
CALL ..\.flutter\bin\flutter.bat pub get
CALL ..\.flutter\bin\flutter.bat packages pub run build_runner build --delete-conflicting-outputs
CALL ..\.flutter\bin\flutter.bat build web
echo "Build finished"
CALL cd ..
CALL del ServerDotnet\WebApi\wwwroot /F /Q
CALL mkdir ServerDotnet\WebApi\wwwroot
CALL robocopy ClientFlutter\build\web ServerDotnet\WebApi\wwwroot /s
echo "Copy finished"
cd scripts