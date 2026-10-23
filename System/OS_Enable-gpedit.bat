@echo off
rem 下にヘルプがあります
chcp 932 >nul
if "%1"=="-h" goto help
if "%1"=="--help" goto help

:Administrator
net session >NUL 2>nul
if %errorlevel% neq 0 goto Administratorstart
goto start
exit
:Administratorstart
echo このバッチファイルは一般ユーザーには対応していないので管理者権限を要求して再起動します
where sudo >NUL 2>nul
if not errorlevel 1 (
  sudo "%~f0" %*
  exit /b
)
where gsudo >NUL 2>nul
if not errorlevel 1 (
  gsudo "%~f0" %*
  exit /b
)
powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
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
echo  %~nx0
echo  %~nx0 -h
echo  %~nx0 --help
echo.
echo  引数なしで管理者権限を確認し、gpedit.msc の有効化を開始します。
echo.
echo  -h, --help  このヘルプを表示します。
echo.
pause
exit /b
