@echo off
rem ã“ã®ãƒãƒƒãƒã®ãƒ˜ãƒ«ãƒ—ã¯ãƒ•ã‚¡ã‚¤ãƒ«æœ«å°¾ã«ã‚ã‚Šã¾ã™ï¼ˆ-h / --help ã¾ãŸã¯æœªå¼•æ•°ã§è¡¨ç¤ºï¼‰
chcp 932 > nul
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

echo å†ç”Ÿã™ã‚‹ãƒ•ã‚¡ã‚¤ãƒ«: %~nx1
echo -------------------------------------------------
echo é©ç”¨ã—ãŸã„ãƒ•ã‚£ãƒ«ã‚¿ãƒ¼ã‚’æ›¸ãå…¥ã‚Œã‚‹ã®ã˜ã‚ƒã€‚
echo é©ç”¨ã—ãªã„å ´åˆã¯ã€ä½•ã‚‚æ›¸ã‹ãšã«Enterã‚’æŠ¼ã™ãŒã‚ˆã„ã€‚
echo.
echo ä¾‹ (éŸ³å£°): volume=2.0
echo ä¾‹ (å‹•ç”»): eq=gamma=1.5,vflip
echo -------------------------------------------------
echo.

set AF_OPTION=
set /p USER_AF="éŸ³å£°ãƒ•ã‚£ãƒ«ã‚¿ãƒ¼ (-af) > "
if not "%USER_AF%"=="" set AF_OPTION=-af "%USER_AF%"

set USER_VF=
set /p USER_VF="å‹•ç”»ãƒ•ã‚£ãƒ«ã‚¿ãƒ¼ (-vf) > "

echo.
echo -------------------------------------------------
echo å†ç”Ÿãƒ¢ãƒ¼ãƒ‰ã‚’é¸æŠã™ã‚‹ã®ã˜ã‚ƒï¼š
echo   [1] ç”»é¢ã‹ã‚‰ã¯ã¿å‡ºã•ãªã„ã‚ˆã†ã«èª¿æ•´ã™ã‚‹ãƒ¢ãƒ¼ãƒ‰ (ãƒ‡ãƒ•ã‚©ãƒ«ãƒˆ)
echo   [2] ã‚¦ã‚£ãƒ³ãƒ‰ã‚¦ã‚µã‚¤ã‚ºã‚’1280x720ã®å¤§ãã„è¾ºã«åˆã‚ã›ã‚‹ãƒ¢ãƒ¼ãƒ‰
echo   [3] å¾“æ¥é€šã‚Šã®ãƒ‰ãƒƒãƒˆãƒã‚¤ãƒ‰ãƒƒãƒˆãƒ¢ãƒ¼ãƒ‰
echo   [4] XREAL 1S 3D: “ü—Í ¶=‰EŠá / ‰E=¶Šá (¶‰EŒğŠ·)
echo   [5] XREAL 1S 3D: “ü—Í ¶=¶Šá / ‰E=‰EŠá (ŒğŠ·‚È‚µ)
echo -------------------------------------------------
set PLAY_MODE=1
set /p PLAY_MODE="ãƒ¢ãƒ¼ãƒ‰é¸æŠ (1-5) > "

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
    echo XREAL 1Sã®3840x1080ãƒ‡ã‚£ã‚¹ãƒ—ãƒ¬ã‚¤ãŒè¦‹ã¤ã‹ã‚‰ã¬ã€‚
    echo XREALå´ã‚’Full SBSã®3Dãƒ¢ãƒ¼ãƒ‰ã«ã—ã¦ã‹ã‚‰ã‚„ã‚Šç›´ã™ã®ã˜ã‚ƒã€‚
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
echo ã“ã‚Œã‹ã‚‰å†ç”Ÿã‚’é–‹å§‹ã™ã‚‹ã€‚å¿ƒã—ã¦è¦³ã‚‹ã®ã˜ã‚ƒï¼
echo.

if "%PLAY_MODE%"=="4" goto :play_xreal
if "%PLAY_MODE%"=="5" goto :play_xreal
ffplay -hide_banner -i "%~1" %AF_OPTION% %VF_OPTION%
goto :eof

:play_xreal
ffplay -hide_banner -left %XREAL_X% -top %XREAL_Y% -fs -i "%~1" %AF_OPTION% %VF_OPTION%
goto :eof

:show_help
echo.
echo [æ¦‚è¦]
echo   ffplay ã§ãƒ¡ãƒ‡ã‚£ã‚¢ã‚’å†ç”Ÿã—ã¾ã™ã€‚ä»»æ„ã® -af / -vf ã‚’å¯¾è©±å…¥åŠ›ã§é©ç”¨å¯èƒ½ã€‚
echo.
echo [ä½¿ã„æ–¹]
echo   %~nx0 ^<media_file^>
echo.
echo [å†ç”Ÿãƒ¢ãƒ¼ãƒ‰]
echo   1: ç”»é¢ã‚µã‚¤ã‚ºã«åã‚ã‚‹ï¼ˆãƒ‡ãƒ•ã‚©ãƒ«ãƒˆï¼‰
echo   2: æœ€å¤§1280x720ã‚’åŸºæº–ã«ã‚¹ã‚±ãƒ¼ãƒªãƒ³ã‚°
echo   3: ãƒ‰ãƒƒãƒˆãƒã‚¤ãƒ‰ãƒƒãƒˆ
echo   4: “ü—Í‚Ì¶”¼•ª‚ª‰EŠáA‰E”¼•ª‚ª¶Šá‚ÌSBS
echo      •\¦‚É¶‰E‚ğ“ü‚ê‘Ö‚¦‚éB
echo   5: “ü—Í‚Ì¶”¼•ª‚ª¶ŠáA‰E”¼•ª‚ª‰EŠá‚ÌSBS
echo      ¶‰E‚ğ“ü‚ê‘Ö‚¦‚¸‚É•\¦‚·‚éB
echo   ‹¤’Ê: Full SBS (3840x1080) ‚ÖŠeŠá‚Ìc‰¡”ä‚ğˆÛ‚µ‚Ä•\¦B
echo         ‰ğ‘œ“x‚â16:10E16:9“™‚Ìc‰¡”ä‚ğ–â‚í‚¸A•K—v‚È‚ç•‘Ñ‚ğ’Ç‰ÁB
echo         ‰f‘œ‚ÍÄƒGƒ“ƒR[ƒh‚µ‚È‚¢B
echo.
echo [è£œè¶³]
echo   ãƒ»ffplay ãŒ PATH ã«é€šã£ã¦ã„ã‚‹å¿…è¦ãŒã‚ã‚Šã¾ã™ã€‚
echo   ãƒ»ãƒ¢ãƒ¼ãƒ‰4/5ã§ã¯ã€XREAL 1Sã®3Dè¡¨ç¤ºãƒ¢ãƒ¼ãƒ‰ã‚’å…ˆã«æœ‰åŠ¹åŒ–ã—ã¦ãã ã•ã„ã€‚
echo   Eƒ‚[ƒh4/5‚ÌI—¹‚Í Esc ‚Ü‚½‚Í q ‚Ås‚¦‚Ü‚·B
echo.
echo ä½•ã‹ã‚­ãƒ¼ã‚’æŠ¼ã™ã¨é–‰ã˜ã¾ã™...
pause
exit /b