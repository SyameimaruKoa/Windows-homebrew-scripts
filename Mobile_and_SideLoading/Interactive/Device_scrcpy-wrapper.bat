@echo off
rem 下にヘルプがあります
setlocal ENABLEDELAYEDEXPANSION

rem ヘルプ表示
if /I "%~1"=="-h" goto help
if /I "%~1"=="--help" goto help

rem 文字コード（日本語環境）。必要に応じて変更可。
chcp 932 >nul

rem ===== 初期設定（パス/プロファイル） =====
set "SCRCPY_EXE=%SCRCPY_EXE%"
if not defined SCRCPY_EXE if exist "C:\Users\kouki\OneDrive\CUIApplication\scrcpy-win64\scrcpy.exe" set "SCRCPY_EXE=C:\Users\kouki\OneDrive\CUIApplication\scrcpy-win64\scrcpy.exe"
if not defined SCRCPY_EXE for %%I in (scrcpy.exe) do set "SCRCPY_EXE=%%~$PATH:I"
if not defined SCRCPY_EXE (
	echo [エラー] scrcpy.exe が見つかりません。PATH を通すか SCRCPY_EXE 環境変数を設定してください。
	echo 例) setx SCRCPY_EXE "C:\\Tools\\scrcpy\\scrcpy.exe"
	goto exit_final
)

set "PROFILE_DIR=%~dp0profiles"
if not exist "%PROFILE_DIR%" mkdir "%PROFILE_DIR%" >nul 2>&1

rem ===== ADB 接続（任意） =====
set "CONNECTED_IP="
echo ネットワーク上のデバイスに接続しますか？
choice /c YN /n /m " [Y/N]:"
if errorlevel 2 goto after_connect
set "IPPORT="
set /p IPPORT="IP または IP:PORT を入力 (空Enterでスキップ): "
if defined IPPORT (
	rem ポート未指定なら :5555 を付与
	echo %IPPORT% | find ":" >nul
	if errorlevel 1 set "IPPORT=%IPPORT%:5555"
	adb connect %IPPORT%
	if %errorlevel%==0 (
		set "CONNECTED_IP=%IPPORT%"
		echo 接続しました: %IPPORT%
	) else (
		echo [注意] 接続に失敗しました。
	)
)

:after_connect

rem ===== メインループ =====
:top
cls
echo === scrcpy 実行オプション ビルダー ===
echo そのまま Enter で現在の設定で実行。番号で設定変更。E で生のオプション入力。
echo.

rem 設定値（都度編集可能）
if not defined RES set "RES="
if not defined BR set "BR="
if not defined FPS set "FPS="
if not defined CROP set "CROP="
if not defined ORI set "ORI="
if not defined FULL set "FULL=0"
if not defined SCREENOFF set "SCREENOFF=0"
if not defined SERIAL set "SERIAL="

rem 組み立て
set "OPTS="
if defined RES set "OPTS=!OPTS! -m !RES!"
if defined BR set "OPTS=!OPTS! -b !BR!"
if defined FPS set "OPTS=!OPTS! --max-fps !FPS!"
if defined CROP set "OPTS=!OPTS! --crop !CROP!"
if defined ORI set "OPTS=!OPTS! --lock-video-orientation !ORI!"
if /I "!FULL!"=="1" set "OPTS=!OPTS! -f"
if /I "!SCREENOFF!"=="1" set "OPTS=!OPTS! -S"
if defined SERIAL set "OPTS=!OPTS! -s !SERIAL!"

echo [現在のオプション]: !OPTS!
echo [現在のデバイス]:  !SERIAL!
echo.
echo  1) 解像度 -m (例: 1920)    現在: !RES!
echo  2) 帯域 -b (例: 8M/2000K) 現在: !BR!
echo  3) FPS --max-fps (例: 60) 現在: !FPS!
echo  4) トリミング --crop (例: 1224:1440:0:0) 現在: !CROP!
echo  5) 画面回転 --lock-video-orientation [0/1/2/3] 現在: !ORI!
echo  6) フルスクリーン -f  [0/1] 現在: !FULL!
echo  7) スマホ画面オフ -S   [0/1] 現在: !SCREENOFF!
echo  8) プリセット保存
echo  9) プリセット読込
echo 10) デバイス一覧・選択
echo  L) 一覧表示(デバイス/プリセット)
echo  T) テンプレ適用
echo  E) 生のオプションを入力して実行
echo  Q) 終了
echo.
set "ANS="
set /p ANS=選択 (Enterで実行): 

if not defined ANS goto run_now
if /I "%ANS%"=="Q" goto exit
if /I "%ANS%"=="E" goto expert
if "%ANS%"=="1" goto set_res
if "%ANS%"=="2" goto set_br
if "%ANS%"=="3" goto set_fps
if "%ANS%"=="4" goto set_crop
if "%ANS%"=="5" goto set_ori
if "%ANS%"=="6" goto toggle_full
if "%ANS%"=="7" goto toggle_screenoff
if "%ANS%"=="8" goto save_preset
if "%ANS%"=="9" goto load_preset
if "%ANS%"=="10" goto select_device
if /I "%ANS%"=="L" goto show_list
if /I "%ANS%"=="T" goto apply_template
goto top

:set_res
set "RES="
set /p RES=解像度(-m): 
goto top

:set_br
set "BR="
set /p BR=帯域(-b): 
goto top

:set_fps
set "FPS="
set /p FPS=FPS(--max-fps): 
goto top

:set_crop
set "CROP="
set /p CROP=トリミング(--crop): 
goto top

:set_ori
set "ORI="
set /p ORI=回転[0/1/2/3](--lock-video-orientation): 
goto top

:toggle_full
if "!FULL!"=="1" (set "FULL=0") else (set "FULL=1")
goto top

:toggle_screenoff
if "!SCREENOFF!"=="1" (set "SCREENOFF=0") else (set "SCREENOFF=1")
goto top

:save_preset
set "PNAME="
set /p PNAME=保存するプリセット名: 
if not defined PNAME goto top
(
	echo !OPTS!
) >"%PROFILE_DIR%\!PNAME!.opts"
echo 保存しました: %PROFILE_DIR%\!PNAME!.opts
timeout /t 1 >nul
goto top

:load_preset
echo 利用可能なプリセット:
for %%F in ("%PROFILE_DIR%\*.opts") do echo   - %%~nF
set "PNAME="
set /p PNAME=読込むプリセット名: 
if not defined PNAME goto top
set "RAW_OPTS="
for /f usebackq delims= eol=^ tokens=* %%A in ("%PROFILE_DIR%\%PNAME%.opts") do set "RAW_OPTS=%%A"
if not defined RAW_OPTS (
	echo [注意] プリセットが見つからないか空です。
	timeout /t 1 >nul
	goto top
)
echo プリセットを読み込みました。
set "OPTS=!RAW_OPTS!"
goto run_now

:select_device
echo デバイスを検索しています...
set "IDX=0"
for /f "skip=1 tokens=1,2" %%A in ('adb devices -l') do (
	if /I "%%B"=="device" (
		set /a IDX+=1
		set "DEV_!IDX!=%%A"
	)
)
if "!IDX!"=="0" (
	echo 有効なデバイスが見つかりませんでした。(adb devices で確認してください)
	timeout /t 1 >nul
	goto top
)
echo 利用可能なデバイス:
for /l %%I in (1,1,!IDX!) do echo   %%I^) !DEV_%%I!
set "CH="
set /p CH=番号を選択(空でキャンセル): 
if not defined CH goto top
for /f "tokens=1 delims=0123456789" %%Z in ("!CH!") do set CH=
if not defined CH goto top
for /f "delims=" %%S in ("!DEV_!CH!!") do set "SERIAL=%%S"
echo 選択中のデバイス: !SERIAL!
timeout /t 1 >nul
goto top

:show_list
echo --- デバイス一覧 ---
set "IDX=0"
for /f "skip=1 tokens=1,2" %%A in ('adb devices -l') do (
	if /I "%%B"=="device" (
		set /a IDX+=1
		echo   !IDX!^) %%A
	)
)
if "!IDX!"=="0" echo   (有効なデバイスなし)
echo.
echo --- プリセット一覧 (profiles) ---
set "HAVE=0"
for %%F in ("%PROFILE_DIR%\*.opts") do (
	set "HAVE=1"
	echo   - %%~nF
)
if "!HAVE!"=="0" echo   (プリセットなし)
echo.
pause
goto top

:apply_template
cls
echo === テンプレ適用 ===
echo  1) 低遅延(軽量): -m 1280 -b 8M --max-fps 60
echo  2) 高画質(大画面): -m 1920 -b 16M --max-fps 60 -f
echo  3) 省帯域: -m 1024 -b 2000K --max-fps 30
echo  4) 縦配信プリセット: --crop 720:1280:0:0 -m 1280 -b 8M --max-fps 60
echo  5) 横配信プリセット: --crop 1280:720:0:0 -m 1280 -b 8M --max-fps 60 --lock-video-orientation 1
echo  Q) 戻る
set "TMPSEL="
set /p TMPSEL=選択: 
if /I "%TMPSEL%"=="Q" goto top
if "%TMPSEL%"=="1" (
	set "RES=1280"
	set "BR=8M"
	set "FPS=60"
	set "CROP="
	set "ORI="
	set "FULL=0"
	set "SCREENOFF=0"
	goto top
)
if "%TMPSEL%"=="2" (
	set "RES=1920"
	set "BR=16M"
	set "FPS=60"
	set "CROP="
	set "ORI="
	set "FULL=1"
	set "SCREENOFF=0"
	goto top
)
if "%TMPSEL%"=="3" (
	set "RES=1024"
	set "BR=2000K"
	set "FPS=30"
	set "CROP="
	set "ORI="
	set "FULL=0"
	set "SCREENOFF=0"
	goto top
)
if "%TMPSEL%"=="4" (
	set "RES=1280"
	set "BR=8M"
	set "FPS=60"
	set "CROP=720:1280:0:0"
	set "ORI=0"
	set "FULL=0"
	set "SCREENOFF=0"
	goto top
)
if "%TMPSEL%"=="5" (
	set "RES=1280"
	set "BR=8M"
	set "FPS=60"
	set "CROP=1280:720:0:0"
	set "ORI=1"
	set "FULL=0"
	set "SCREENOFF=0"
	goto top
)
goto apply_template
:expert
set "OPTS="
set /p OPTS=そのまま渡す scrcpy オプションを入力: 
goto run_now

:run_now
echo ------------------------------------------------------------
echo 実行コマンド:
echo   "%SCRCPY_EXE%" --push-target /sdcard/Download/ !OPTS!
echo ------------------------------------------------------------
call "%SCRCPY_EXE%" --push-target /sdcard/Download/ !OPTS!
echo.
choice /c YN /n /m "もう一度設定を続けますか？ [Y/N]:"
if errorlevel 2 goto exit
goto top

:exit
if defined CONNECTED_IP (
	echo ネットワーク接続を切断します: %CONNECTED_IP%
	adb disconnect %CONNECTED_IP% >nul 2>&1
)
goto exit_final

:help
echo.
echo scrcpy を簡単に使うための対話型バッチです。
echo.
echo 使い方:
echo   %~n0           対話型メニューを起動します。
echo   %~n0 -h|--help このヘルプを表示します。
echo.
echo 特徴:
echo   - 解像度(-m), 帯域(-b), FPS(--max-fps), トリミング(--crop), 回転(--lock-video-orientation),
echo     フルスクリーン(-f), 画面オフ(-S) をメニューで指定.
echo   - E で生のオプションをそのまま入力して実行可能.
echo   - プリセット保存/読込に対応 (profiles\*.opts)。一覧表示(L)可。
echo   - テンプレ適用(T): 低遅延/高画質/省帯域/配信用などを一発設定。
echo   - デバイス一覧・選択(10): adb devices -l から選んで -s を自動付与。
echo   - ネットワーク端末への adb connect を補助 (起動時に任意)。
echo   - SCRCPY_EXE 環境変数で scrcpy.exe の場所を上書き可能。
echo.
echo 備考:
echo   - 本バッチは "%PROFILE_DIR%" にプリセットを保存します。
echo   - 管理者権限は不要です。adb/scrcpy は事前に導入してください。
echo.
pause
goto exit_final

:exit_final
endlocal
exit /b