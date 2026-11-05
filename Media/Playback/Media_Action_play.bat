@echo off
rem 縺薙�繝舌ャ繝√�繝倥Ν繝励�繝輔ぃ繧､繝ｫ譛ｫ蟆ｾ縺ｫ縺ゅｊ縺ｾ縺呻ｼ-h / --help 縺ｾ縺溘�譛ｪ蠑墓焚縺ｧ陦ｨ遉ｺ�
chcp 932 > nul
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

echo 蜀咲函縺吶ｋ繝輔ぃ繧､繝ｫ: %~nx1
echo -------------------------------------------------
echo 驕ｩ逕ｨ縺励◆縺�ヵ繧｣繝ｫ繧ｿ繝ｼ繧呈嶌縺榊�繧後ｋ縺ｮ縺倥ｃ縲
echo 驕ｩ逕ｨ縺励↑縺�ｴ蜷医�縲∽ｽ輔ｂ譖ｸ縺九★縺ｫEnter繧呈款縺吶′繧医＞縲
echo.
echo 萓 (髻ｳ螢ｰ): volume=2.0
echo 萓 (蜍慕判): eq=gamma=1.5,vflip
echo -------------------------------------------------
echo.

set AF_OPTION=
set /p USER_AF="髻ｳ螢ｰ繝輔ぅ繝ｫ繧ｿ繝ｼ (-af) > "
if not "%USER_AF%"=="" set AF_OPTION=-af "%USER_AF%"

set USER_VF=
set /p USER_VF="蜍慕判繝輔ぅ繝ｫ繧ｿ繝ｼ (-vf) > "

echo.
echo -------------------------------------------------
echo 蜀咲函繝｢繝ｼ繝峨ｒ驕ｸ謚槭☆繧九�縺倥ｃ�
echo   [1] 逕ｻ髱｢縺九ｉ縺ｯ縺ｿ蜃ｺ縺輔↑縺�ｈ縺�↓隱ｿ謨ｴ縺吶ｋ繝｢繝ｼ繝 (繝�ヵ繧ｩ繝ｫ繝)
echo   [2] 繧ｦ繧｣繝ｳ繝峨え繧ｵ繧､繧ｺ繧1280x720縺ｮ螟ｧ縺阪＞霎ｺ縺ｫ蜷医ｏ縺帙ｋ繝｢繝ｼ繝
echo   [3] 蠕捺擂騾壹ｊ縺ｮ繝峨ャ繝医ヰ繧､繝峨ャ繝医Δ繝ｼ繝
echo   [4] XREAL 1S 3D: 入力 左=右眼 / 右=左眼 (左右交換)
echo   [5] XREAL 1S 3D: 入力 左=左眼 / 右=右眼 (交換なし)
echo -------------------------------------------------
set PLAY_MODE=1
set /p PLAY_MODE="繝｢繝ｼ繝蛾∈謚 (1-5) > "

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
    echo XREAL 1S縺ｮ3840x1080繝�ぅ繧ｹ繝励Ξ繧､縺瑚ｦ九▽縺九ｉ縺ｬ縲
    echo XREAL蛛ｴ繧巽ull SBS縺ｮ3D繝｢繝ｼ繝峨↓縺励※縺九ｉ繧�ｊ逶ｴ縺吶�縺倥ｃ縲
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
echo 縺薙ｌ縺九ｉ蜀咲函繧帝幕蟋九☆繧九ょｿ�＠縺ｦ隕ｳ繧九�縺倥ｃ�
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
echo [讎りｦ‐
echo   ffplay 縺ｧ繝｡繝�ぅ繧｢繧貞�逕溘＠縺ｾ縺吶ゆｻｻ諢上� -af / -vf 繧貞ｯｾ隧ｱ蜈･蜉帙〒驕ｩ逕ｨ蜿ｯ閭ｽ縲
echo.
echo [菴ｿ縺�婿]
echo   %~nx0 ^<media_file^>
echo.
echo [蜀咲函繝｢繝ｼ繝云
echo   1: 逕ｻ髱｢繧ｵ繧､繧ｺ縺ｫ蜿弱ａ繧具ｼ医ョ繝輔か繝ｫ繝茨ｼ
echo   2: 譛螟ｧ1280x720繧貞渕貅悶↓繧ｹ繧ｱ繝ｼ繝ｪ繝ｳ繧ｰ
echo   3: 繝峨ャ繝医ヰ繧､繝峨ャ繝
echo   4: 入力の左半分が右眼、右半分が左眼のSBS
echo      表示時に左右を入れ替える。
echo   5: 入力の左半分が左眼、右半分が右眼のSBS
echo      左右を入れ替えずに表示する。
echo   共通: Full SBS (3840x1080) へ各眼の縦横比を維持して表示。
echo         解像度や16:10・16:9等の縦横比を問わず、必要なら黒帯を追加。
echo         映像は再エンコードしない。
echo.
echo [陬懆ｶｳ]
echo   GPU: D3D11VA��D�悵�A�Đ��G���[����CPU�ɐ؂�ւ���B
echo   繝ｻffplay 縺 PATH 縺ｫ騾壹▲縺ｦ縺�ｋ蠢�ｦ√′縺ゅｊ縺ｾ縺吶
echo   繝ｻ繝｢繝ｼ繝4/5縺ｧ縺ｯ縲々REAL 1S縺ｮ3D陦ｨ遉ｺ繝｢繝ｼ繝峨ｒ蜈医↓譛牙柑蛹悶＠縺ｦ縺上□縺輔＞縲
echo   ・モード4/5の終了は Esc または q で行えます。
echo.
echo 菴輔°繧ｭ繝ｼ繧呈款縺吶→髢峨§縺ｾ縺...
pause
exit /b