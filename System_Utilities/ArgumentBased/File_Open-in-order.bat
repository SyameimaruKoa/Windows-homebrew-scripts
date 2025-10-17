@echo off
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