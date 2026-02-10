@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
%~d1
cd "%~dp0"
:roop
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
del "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo MUXOPT --no-pcr-on-video-pid --new-audio-pes --vbr  --vbv-len=500 > "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo V_MPEG4/ISO/AVC, "%~1", insertSEI, contSPS, track=1, lang=und >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo A_AAC, "%~1", track=2, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
"C:\Users\kouki\Documents\tsMuxeR_2.6.12\tsMuxeR.exe" "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta" "C:\Users\kouki\Desktop\BD\%~n1.m2ts"
shift
if not "%~1"=="" goto roop
timeout /nobreak 3
exit /b

:show_help
echo.
echo [概要]
echo   tsMuxeR で動画とAAC音声を m2ts に多重化します（固定パスのmetaを生成）。
echo.
echo [使い方]
echo   %~nx0 ^<video_or_ts^>
echo.
echo [出力]
echo   C:\Users\kouki\Desktop\BD\^<元名^>.m2ts
echo.
echo [前提]
echo   ・C:\Users\kouki\Documents\tsMuxeR_2.6.12\ に tsMuxeR.exe が存在すること。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b