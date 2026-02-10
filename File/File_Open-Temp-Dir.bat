@echo off
rem 下にヘルプがあります（-h / --help または未引数で表示）
if "%~1"=="" goto help
if "%~1"=="-h" goto help
if "%~1"=="--help" goto help
chcp 932
echo "TEMP/TMP をユーザー既定に設定し、一時フォルダを開きます"
set "TEMP=%USERPROFILE%\AppData\Local\Temp"
set "TMP=%USERPROFILE%\AppData\Local\Temp"
start "" "%TEMP%"
exit /b

:help
echo.
echo 一時フォルダ(TEMP)を開きます。
echo.
echo 使い方:
echo   %~n0 [引数]
echo.
echo   未引数でも実行されます。-h/--help でこのヘルプ。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b