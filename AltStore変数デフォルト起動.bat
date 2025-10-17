@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help
if "%1"=="" goto help

chcp 932
:Administrator
net session >NUL 2>nul
if %errorlevel% neq 0 goto Administratorstart
goto start
exit
:Administratorstart
echo このバッチファイルは一般ユーザーには対応していないので管理者権限を要求して再起動します
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
start "" "C:\Program Files (x86)\AltServer\AltServer.exe"
echo 起動できました。
echo AltStoreをダウンロードします。
call "C:\Users\kouki\OneDrive\バッチ_バックアップ設定\SideStoreダウンロード.bat"
timeout /nobreak 3
exit

:help
echo.
echo AltServerの起動とSideStoreのダウンロード準備を行うバッチファイルです。
echo.
echo 実行には管理者権限が必要です。
echo 実行すると、以下の処理が行われます。
echo 1. 一時フォルダのパスを設定
echo 2. AltServer.exeを起動
echo 3. SideStoreダウンロード用のバッチファイルを呼び出し
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