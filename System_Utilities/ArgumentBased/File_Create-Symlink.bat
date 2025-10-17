@echo off
chcp 932
echo リンクを作成するパスを入力してください。"と最後に＼は必要ないです
set /P path=
:roop
if "%~x1"=="" mklink /D "%path%\%~nx1" %1
if not "%~x1"=="" mklink "%path%\%~nx1" %1
shift
if not "%~1"=="" goto roop
pause
exit