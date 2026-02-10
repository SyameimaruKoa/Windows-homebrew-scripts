@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help
if "%1"=="" goto help

chcp 932
taskkill /f /IM explorer.exe
start explorer.exe
@timeout /nobreak 2
@exit

:help
echo.
echo エクスプローラーを再起動します。
echo.
echo 使い方:
echo   %~n0 [引数]
echo.
echo   何かしらの引数を指定して実行してください。
echo   例: %~n0 start
echo.
echo   -h, --help    このヘルプを表示します。
echo.
pause
exit /b