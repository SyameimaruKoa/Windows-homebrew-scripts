@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
cd /d %~dp1
If not exist ffmpeg mkdir ffmpeg
ffmpeg -i %1 -filter_complex "channelsplit=channel_layout=7.1[FL][FR][FC][LFE][BL][BR][SL][SR]" -map "[FL]" "ffmpeg\%~n1-1front_left.flac" -map "[FR]" "ffmpeg\%~n1-2front_right.flac" -map "[FC]" "ffmpeg\%~n1-3front_center.flac" -map "[LFE]" "ffmpeg\%~n1-4lfe.flac" -map "[BL]" "ffmpeg\%~n1-5back_left.flac" -map "[BR]" "ffmpeg\%~n1-6back_right.flac" -map "[SL]" "ffmpeg\%~n1-7side_left.flac" -map "[SR]" "ffmpeg\%~n1-8side_right.flac"
pause
exit

:show_help
echo.
echo [概要]
echo   7.1ch音声の各チャンネルを個別のFLACに分離します。
echo.
echo [使い方]
echo   %~nx0 ^<audio_or_media_file^>
echo.
echo [出力]
echo   同階層の ffmpeg\ に 8個のFLACを出力します。
echo.
echo [前提]
echo   ・ffmpeg が PATH に通っていること。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b