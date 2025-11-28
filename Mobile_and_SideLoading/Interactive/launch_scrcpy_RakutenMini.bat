@echo off
rem 文字コードはShift-JISで保存するのじゃぞ
chcp 932

rem --- 設定エリア ---
rem SSHのホスト名 (configファイル設定済みならエイリアスでOK)
set SSH_HOST=rmini
rem Tailscale IP
set HOST=rakuten-mini.bass-uaru.ts.net
rem Android側のスクリプトパス
set REMOTE_SCRIPT=/data/adb/tailscale/unlock.sh
rem Scrcpyのビットレート (2M推奨)
set BIT_RATE=1M
rem ------------------

rem 引数ヘルプチェック
if "%~1"=="-h" goto :help
if "%~1"=="--help" goto :help

echo [INFO] ロック解除スクリプトを実行中 (via SSH)...
rem SSH経由でAndroid内のスクリプトを叩く
rem パスワード入力なしでログインできるよう、公開鍵認証設定済みが前提じゃ
ssh %SSH_HOST% "%REMOTE_SCRIPT%"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] SSH接続またはスクリプト実行に失敗したぞ。
    pause
    exit /b
)

echo [INFO] Scrcpyを起動中... (画面はオフになります)
rem Scrcpyを起動。接続先IPはScrcpyが自動解決、または引数不要の場合を想定
rem もしIP指定が必要なら scrcpy -s %SSH_HOST% など適宜書き換えるのじゃ
scrcpy -s %HOST% --video-bit-rate %BIT_RATE% --max-size 800 -S -w
goto :eof

:help
echo Usage: %~nx0
echo.
echo Description:
echo     Launches Scrcpy and triggers the remote unlock script via SSH.
echo     Requires password-less SSH access to the Android device.
echo.
echo Options:
echo     -h, --help    Show this help message.
echo.
echo -----------------------------------------------------
echo  Wait for user input before closing...
pause

exit /b
