@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help
if "%1"=="" goto help

chcp 65001
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
pushd "%~dp0"

dir /b %SystemRoot%\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientExtensions-Package~3*.mum >List.txt
dir /b %SystemRoot%\servicing\Packages\Microsoft-Windows-GroupPolicy-ClientTools-Package~3*.mum >>List.txt

for /f %%i in ('findstr /i . List.txt 2^>nul') do dism /online /norestart /add-package:"%SystemRoot%\servicing\Packages\%%i"
start gpedit.msc
timeout /nobreak 3
exit

:help
echo.
echo Windows Home Editionでローカルグループポリシーエディター(gpedit.msc)を有効にします。
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