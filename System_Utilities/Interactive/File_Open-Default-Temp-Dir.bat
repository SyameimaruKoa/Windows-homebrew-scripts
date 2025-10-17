@echo off
chcp 932
:Administrator
net session >NUL 2>nul
if %errorlevel% neq 0 goto Administratorstart
goto start
exit
:Administratorstart
echo このバッチファイルは一般ユーザーには対応していないので管理者権限を要求して再起動します
set path1="%1"
@powershell start-process powershell %~0 -verb runas
if %errorlevel%==1 (
echo 権限要求を拒否されたので再度要求します。
goto Administrator
)
exit
:start
echo "変数を変更します"
set TEMP=%USERPROFILE%\AppData\Local\Temp
set TMP=%USERPROFILE%\AppData\Local\Temp
echo "AltServerを起動します"
start "" %path1%
echo 起動できました。
timeout /nobreak 3
exit