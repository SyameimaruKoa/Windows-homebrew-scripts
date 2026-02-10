@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 65001
set "_SCRIPT=%~1"
shift
rem 追加引数はそのまま WSL に渡す
wsl "./%_SCRIPT%" %*
pause
exit /b

:show_help
echo.
echo [概要]
echo   指定した WSL 上のシェルスクリプトを現在ディレクトリで実行します。
echo.
echo [使い方]
echo   %~nx0 ^<script.sh^> [args...]
echo.
echo [例]
echo   %~nx0 Screenshot-Convert.sh
echo.
echo [注意]
echo   事前に WSL ディストリとスクリプト位置を整備しておく必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b