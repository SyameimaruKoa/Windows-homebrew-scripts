@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~3"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
:roop
ffmpeg -hide_banner -i %1 -i %2 -i %3 -c copy ^
-map 0:v:0 ^
-map 2:a:0 ^
-map 1:a:0 ^
-metadata:s:a:0 title="ステレオ" ^
-metadata:s:a:1 title="モノラル" ^
"C:\Users\kouki\Videos\エンコード済み\%~n1 Multitrack.mp4"
shift
shift
shift
if not "%~1"=="" goto roop
pause
exit /b

:show_help
echo.
echo [概要]
echo   入力1(動画), 入力2(モノラル), 入力3(ステレオ)から、
echo   ステレオ/モノラルを並べたマルチトラックMP4を作成します。
echo.
echo [使い方]
echo   %~nx0 ^<video^> ^<mono_audio^> ^<stereo_audio^>
echo.
echo [出力]
echo   C:\Users\kouki\Videos\エンコード済み\^<動画名^> Multitrack.mp4
echo.
echo [前提]
echo   ・ffmpeg が PATH に通っていること。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b