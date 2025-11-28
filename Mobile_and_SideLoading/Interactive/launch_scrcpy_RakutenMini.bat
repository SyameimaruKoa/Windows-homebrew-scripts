@echo off
rem 文字コードはShift-JISで保存するのじゃぞ
chcp 932 >nul

rem --- 設定エリア ---
set SSH_HOST=rmini
rem Tailscale IP (ADB用)
set HOST=rakuten-mini.bass-uaru.ts.net:5555
rem 通常解除用
set SCRIPT_NORMAL=/sdcard/unlock.sh
rem BFU/非常用
set SCRIPT_BFU=/data/adb/tailscale/unlock.sh
rem ロック用
set SCRIPT_LOCK=/sdcard/lock.sh

rem ★PINコード (空欄なら毎回手入力モード)★
set PIN_CODE=

rem Scrcpy設定
set BIT_RATE=1M
rem ------------------

if "%~1"=="-h" goto :help
if "%~1"=="--help" goto :help

echo [INFO] ロック解除を試みておる...

rem 1. 通常解除を実行 (エラーコードは無視)
ssh -t %SSH_HOST% sh "%SCRIPT_NORMAL% %PIN_CODE%"

echo.
echo [INFO] 解除を確認しておる(最大3秒待機)...

rem --- 監視ループ開始 ---
set RETRY_COUNT=0

:check_loop
rem ロックフラグを探す (見つかれば Locked=0, なければ Unlocked=1)
ssh %SSH_HOST% "dumpsys window | grep isStatusBarKeyguard=true" >nul 2>&1

rem エラーレベルが1 (grep失敗＝文字が見つからない) なら解除成功じゃ！
if %ERRORLEVEL% neq 0 goto :unlock_success

rem まだロック中ならカウントアップ
set /a RETRY_COUNT=RETRY_COUNT+1

rem 2回試してもダメならBFUへ
if %RETRY_COUNT% gtr 2 goto :bfu_fallback

echo [INFO] まだ反映待ちじゃ... (%RETRY_COUNT%/2)
timeout /t 2 >nul
goto :check_loop
rem --- 監視ループ終了 ---


:bfu_fallback
echo.
echo [WARN] 応答なし。BFUモードで強制解除するぞ！
echo.
ssh -t %SSH_HOST% "sh %SCRIPT_BFU%"
rem BFU後は問答無用でScrcpyへ進む
goto :start_scrcpy


:unlock_success
echo [INFO] 解除を確認したぞ！(既に開いておる)
goto :start_scrcpy


:start_scrcpy
echo [INFO] Scrcpyを起動中... (閉じると自動でロックされる)
rem ※ Audio disabled などのログが出るが、Android 9 仕様なので気にするな
adb connect %HOST% >nul
scrcpy -s %HOST% --video-bit-rate %BIT_RATE% --max-size 800 -S -w

echo.
echo [INFO] Scrcpyが終了したの。端末をロックするぞ...
ssh %SSH_HOST% sh "%SCRIPT_LOCK%"

timeout /t 3 >nul
goto :eof

:help
echo Usage: %~nx0
echo.
echo Description:
echo     Smart unlock & launch wrapper for Rakuten Mini.
echo     Uses a polling loop to verify unlock status robustly.
echo.
pause
exit /b