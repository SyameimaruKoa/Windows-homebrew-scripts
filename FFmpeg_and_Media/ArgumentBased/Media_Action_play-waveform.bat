@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
cd /d "%TEMP%"
ffmpeg -hide_banner -i "%~1" -vn -f wav "%~n1 ffmpeg tmp.wav"
call "C:\Users\kouki\OneDrive\PortableApps\WS151\WS.EXE" "%TEMP%\%~n1 ffmpeg tmp.wav"
del "%~n1 ffmpeg tmp.wav"
exit

:show_help
echo.
echo [概要]
echo   音声の波形を表示するプレイヤー(WS)で再生します。内部で一時wavを作成します。
echo.
echo [使い方]
echo   %~nx0 ^<audio_file^>
echo.
echo [補足]
echo   ・ffmpeg と WS.EXE が必要です。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b