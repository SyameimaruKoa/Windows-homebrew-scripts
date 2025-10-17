@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help

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
if "%1"=="" goto help

echo 有効なリンクされてるネットワーク情報
PowerShell -command "Get-NetConnectionProfile"
echo ──────────────────────────────
echo ネットワークセキュリティを変更したいネットワークアダプタの「InterfaceIndex」を入力してください
set interfaceindex=
set /P interfaceindex=
echo ネットワークセキュリティの種類を入力してくだしあ
choice /c ru /m "[r]Private or [u]Public"
if %errorlevel%==1 set networkcategory=Private
if %errorlevel%==2 set networkcategory=Public
PowerShell -command "Set-NetConnectionProfile -InterfaceIndex %interfaceindex% -NetworkCategory %networkcategory%"
echo 実行後のネットワーク情報
PowerShell -command "Get-NetConnectionProfile"
echo ──────────────────────────────
echo 以上の状態にネットワークセキュリティを変更しました。
pause
exit

:help
echo.
echo ネットワーク接続のカテゴリ（パブリック/プライベート）を変更します。
echo.
echo 使い方:
echo   %~n0 [引数]
echo.
echo   何かしらの引数を指定して実行してください。
echo   実行すると、対話形式で設定を変更できます。
echo   例: %~n0 start
echo.
echo   -h, --help    このヘルプを表示します。
echo.
pause
exit /b