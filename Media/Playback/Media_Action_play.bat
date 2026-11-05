@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
chcp 932 > nul
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

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
echo   [4] XREAL 1S 3D: 入力 左=右眼 / 右=左眼 (左右交換)
echo   [5] XREAL 1S 3D: 入力 左=左眼 / 右=右眼 (交換なし)
echo -------------------------------------------------
set PLAY_MODE=1
set /p PLAY_MODE="モード選択 (1-5) > "

set "AUTO_SCALE="
if "%PLAY_MODE%"=="1" goto :mode_fit_screen
if "%PLAY_MODE%"=="2" goto :mode_scale_1280
if "%PLAY_MODE%"=="4" goto :mode_xreal
if "%PLAY_MODE%"=="5" goto :mode_xreal
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

:mode_xreal
set "XREAL_X="
set "XREAL_Y="
for /f "tokens=1,2 delims=," %%A in ('powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; foreach ($s in [System.Windows.Forms.Screen]::AllScreens) { if ($s.Bounds.Width -eq 3840 -and $s.Bounds.Height -eq 1080) { Write-Output ([string]$s.Bounds.X + [char]44 + [string]$s.Bounds.Y); break } }"') do (
    set "XREAL_X=%%A"
    set "XREAL_Y=%%B"
)
if not defined XREAL_X (
    echo XREAL 1Sの3840x1080ディスプレイが見つからぬ。
    echo XREAL側をFull SBSの3Dモードにしてからやり直すのじゃ。
    exit /b 1
)
set "XREAL_ORDER=[right][left]"
if "%PLAY_MODE%"=="5" set "XREAL_ORDER=[left][right]"
set "AUTO_SCALE=split=2[l][r];[l]crop=iw/2:ih:0:0,scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black[left];[r]crop=iw/2:ih:iw/2:0,scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black[right];%XREAL_ORDER%hstack=inputs=2,setsar=1
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

set "XREAL_PLAY_ARGS="
if "%PLAY_MODE%"=="4" set "XREAL_PLAY_ARGS=-left %XREAL_X% -top %XREAL_Y% -fs"
if "%PLAY_MODE%"=="5" set "XREAL_PLAY_ARGS=-left %XREAL_X% -top %XREAL_Y% -fs"
goto :play_with_hw

:play_with_hw
set "GPU_LOG=%TEMP%\Media_Action_play_%RANDOM%_%RANDOM%_gpu.log"
ffplay -hide_banner -loglevel error -nostats -hwaccel d3d11va %XREAL_PLAY_ARGS% -i "%~1" %AF_OPTION% %VF_OPTION% 2>"%GPU_LOG%"
set "GPU_EXIT=%ERRORLEVEL%"
if not "%GPU_EXIT%"=="0" goto :play_cpu
for %%L in ("%GPU_LOG%") do if %%~zL GTR 0 goto :play_cpu
if exist "%GPU_LOG%" del /q "%GPU_LOG%" >nul 2>&1
goto :eof

:play_cpu
echo [GPU] Hardware decoding failed. Retrying with CPU.
if exist "%GPU_LOG%" type "%GPU_LOG%"
if exist "%GPU_LOG%" del /q "%GPU_LOG%" >nul 2>&1
ffplay -hide_banner %XREAL_PLAY_ARGS% -i "%~1" %AF_OPTION% %VF_OPTION%
exit /b %ERRORLEVEL%

:show_help
echo.
echo [概要]
echo   ffplay でメディアを再生します。任意の -af / -vf を対話入力で適用可能。
echo.
echo [使い方]
echo   %~nx0 ^<media_file^>
echo.
echo [再生モード]
echo   1: 画面サイズに収める（デフォルト）
echo   2: 最大1280x720を基準にスケーリング
echo   3: ドットバイドット
echo   4: 入力の左半分が右眼、右半分が左眼のSBS
echo      表示時に左右を入れ替える。
echo   5: 入力の左半分が左眼、右半分が右眼のSBS
echo      左右を入れ替えずに表示する。
echo   共通: Full SBS (3840x1080) へ各眼の縦横比を維持して表示。
echo         解像度や16:10・16:9等の縦横比を問わず、必要なら黒帯を追加。
echo         映像は再エンコードしない。
echo.
echo [補足]
echo   ・ffplay が PATH に通っている必要があります。
echo   ・モード4/5では、XREAL 1Sの3D表示モードを先に有効化してください。
echo   ・モード4/5の終了は Esc または q で行えます。
echo   GPU: D3D11VAを優先し、再生エラー時はCPUに切り替える。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b