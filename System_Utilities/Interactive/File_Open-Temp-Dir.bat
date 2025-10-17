@echo off
chcp 932
echo "変数を変更します"
set TEMP=%USERPROFILE%\AppData\Local\Temp
set TMP=%USERPROFILE%\AppData\Local\Temp
echo "ソフトを起動します"
start "" "%~1"
echo 起動できました。
timeout /t 1 >nul
exit