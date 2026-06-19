@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932 > nul

echo 再生するファイル: %~nx1
echo -------------------------------------------------
echo 適用したいフィルターを書き入れるのじゃ。
echo 適用しない場合は、何も書かずにEnterを押すがよい。
echo.
echo 例 (音声): volume=2.0
echo 例 (動画): eq=gamma=1.5,vflip
echo -------------------------------------------------
echo.

set AF_OPTION=
set /p USER_AF="音声フィルター (-af) > "
if not "%USER_AF%"=="" set AF_OPTION=-af "%USER_AF%"

set USER_VF=
set /p USER_VF="動画フィルター (-vf) > "

echo.
echo -------------------------------------------------
echo 再生モードを選択するのじゃ：
echo   [1] 画面からはみ出さないように調整するモード (デフォルト)
echo   [2] ウィンドウサイズを1280x720の大きい辺に合わせるモード
echo   [3] 従来通りのドットバイドットモード
echo -------------------------------------------------
set PLAY_MODE=1
set /p PLAY_MODE="モード選択 (1-3) > "

set "AUTO_SCALE="
if "%PLAY_MODE%"=="1" goto :mode_fit_screen
if "%PLAY_MODE%"=="2" goto :mode_scale_1280
goto :mode_done

:mode_fit_screen
set SCREEN_W=1920
set SCREEN_H=1080
for /f "tokens=1,2 delims=," %%A in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea; '{0},{1}' -f $wa.Width, $wa.Height"') do (
    set SCREEN_W=%%A
    set SCREEN_H=%%B
)
set /a MAX_W=SCREEN_W - 40
set /a MAX_H=SCREEN_H - 80
set "AUTO_SCALE=scale='min(%MAX_W%,iw)':'min(%MAX_H%,ih)':force_original_aspect_ratio=decrease"
goto :mode_done

:mode_scale_1280
set "AUTO_SCALE=scale='if(gte(iw/ih,16/9),1280,-2)':'if(gte(iw/ih,16/9),-2,720)'"
goto :mode_done

:mode_done
set "COMBINED_VF=%AUTO_SCALE%"
if "%COMBINED_VF%"=="" set "COMBINED_VF=%USER_VF%" & goto :skip_combine
if not "%USER_VF%"=="" set "COMBINED_VF=%AUTO_SCALE%,%USER_VF%"
:skip_combine

set VF_OPTION=
if not "%COMBINED_VF%"=="" set VF_OPTION=-vf "%COMBINED_VF%"

echo.
echo -------------------------------------------------
echo これから再生を開始する。心して観るのじゃ！
echo.

ffplay -hide_banner -i "%~1" %AF_OPTION% %VF_OPTION%

goto :eof

:show_help
echo.
echo [概要]
echo   ffplay でメディアを再生します。任意の -af / -vf を対話入力で適用可能。
echo.
echo [使い方]
echo   %~nx0 ^<media_file^>
echo.
echo [補足]
echo   ・ffplay が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b