@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~2"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932

:roop
%~d1
cd "%~dp1"
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i "%~1" -f ffmetadata "%~n1 ffmpeg.txt"
cls
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i "%~1" -an -c:v copy "%~n1 ffmpeg.png"
if %errorlevel%==1 goto nopng
cls
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i "%~2" -i "%~n1 ffmpeg.txt" -i "%~n1 ffmpeg.png" -map 0:a -map 2:v -disposition:1 attached_pic -map_metadata 1 -codec copy "%~n2 ffmpeg%~x2"
:end
if not %errorlevel%==1 (
del "%~n1 ffmpeg.txt"
del "%~n1 ffmpeg.png"
del "%~2"
ren "%~n2 ffmpeg%~x2" "%~nx2"
) else (
echo 何らかのファイルが不足しています。
pause
)
shift
shift
if not "%~1"=="" goto roop
exit /b

:nopng
ffmpeg -hide_banner -i "%~2" -i "%~n1 ffmpeg.txt" -map_metadata 1 -codec copy  "%~n2 ffmpeg%~x2"
goto end

:show_help
echo.
echo [概要]
echo   音声や動画からメタデータを抽出し、別のファイルにコピーします。ジャケット画像にも対応。
echo.
echo [使い方]
echo   %~nx0 ^<src_media^> ^<dst_media^>
echo.
echo [補足]
echo   ・ffmpeg が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b