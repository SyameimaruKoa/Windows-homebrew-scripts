@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
if "%~x1"==".m4a" goto tast1audioset
if "%~x1"==".png" goto tast1imageset
if "%~x1"==".jpg" goto tast1imageset
if "%~x1"==".jpeg" goto tast1imageset
echo 1つ目のファイルが非対応の拡張子です。確認してやり直してください。
pause
exit

:show_help
echo.
echo [概要]
echo   静止画(PNG/JPG)と音声(M4A)から動画を作成します。映像はループ、音声はコピー、最短で停止。
echo.
echo [使い方]
echo   %~nx0 ^<image.png^|jpg^> ^<audio.m4a^>
echo   画像と音声の順序はどちらでも可。D^&Dでも OK。
echo.
echo [出力]
echo   同一フォルダに ffmpeg\^<元名^>.mp4 を生成。
echo.
echo [前提]
echo   ffmpeg が PATH に必要。エンコードオプションは外部バッチを call しています。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
:tast1imageset
set "image=%~1"
goto tastset1
:tast1audioset
set "audio=%~1"
goto tastset1
:tastset1
if "%~x2"==".m4a" goto tast2audioset
if "%~x2"==".png" goto tast2imageset
if "%~x2"==".jpg" goto tast2imageset
if "%~x2"==".jpeg" goto tast2imageset
echo 2つ目のファイルが非対応の拡張子です。確認してやり直してください。
pause
exit
:tast2imageset
if not "%image%"=="" goto end
set "image=%~2"
goto root
:tast2audioset
if not "%audio%"=="" goto end
set "audio=%~2"
goto root

:end
echo 画像か音声で同じのが指定されています。やり直してください
echo 1.%~1
echo 2.%~2
echo 3.%~3
echo 4.%~4
pause
exit

:root
rem ffmpeg一括再エンコードVer6.4
rem %tune%はffpmeg5より前に動画予測の形式を指定するための変数です
call "C:\Users\kouki\OneDrive\バッチ_バックアップ設定\D&D実行\ffmpegエンコードオプション.bat"
echo ─────────────────────────────────────
:roop
cls
%~d1
cd "%~dp1"
If not exist ffmpeg mkdir ffmpeg
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
if "%~x1"==".m4a" goto 1audioset
if "%~x1"==".png" goto 1imageset
if "%~x1"==".jpg" goto 1imageset
if "%~x1"==".jpeg" goto 1imageset
echo 1つ目のファイルが非対応の拡張子です。確認してやり直してください。
pause
exit
:1imageset
set "image=%~1"
goto set1
:1audioset
set "audio=%~1"
goto set1
:set1
if "%~x2"==".m4a" goto 2audioset
if "%~x2"==".png" goto 2imageset
if "%~x2"==".jpg" goto 2imageset
if "%~x2"==".jpeg" goto 2imageset
echo 2つ目のファイルが非対応の拡張子です。確認してやり直してください。
pause
exit
:2imageset
set "image=%~2"
goto ffmpegencode
:2audioset
set "audio=%~2"
goto ffmpegencode
:ffmpegencode
ffmpeg -hide_banner -loop 1 -r 24 -i "%image%" -i "%audio%" %encoder% -map_chapters -1 -c:a copy -shortest "ffmpeg\%~n1.mp4"
if %errorlevel%==1 (
call C:\Users\kouki\OneDrive\CUIApplication\notify.bat [%filecount%]EncodeError_Retry
timeout /nobreak 5
goto root
)
shift
shift
if not "%~1"=="" goto roop
call C:\Users\kouki\OneDrive\CUIApplication\notify.bat [%filecount%]encode_end
pause
exit