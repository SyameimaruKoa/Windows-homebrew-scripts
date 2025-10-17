@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
echo "ファイルを連続で開きます(負荷注意)"

:roop
echo "ファイルを開きます: %~nx1"
start "" "%~1"
timeout /t 1 /nobreak >nul

shift
if not "%~1"=="" goto roop
timeout /t 2
exit /b

:show_help
echo.
echo [概要]
echo   複数ファイルを順番に開きます。既定アプリで open されます。
echo.
echo [使い方]
echo   %~nx0 ^<file1^> ^<file2^> ^<file3^> ...
echo.
echo [メモ]
echo   開く間隔は 1 秒固定。大量のファイルでの実行は負荷に注意。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b