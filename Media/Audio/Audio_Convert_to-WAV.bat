@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932

rem 選択スキップ用(通常時はgoto skipまでをコメントアウト)
@REM set bit=-acodec pcm_s24le
@REM set ar= -ar 48000
@REM goto skip

echo "量子化ビット数を指定してください"
choice /c 123 /m "[16bit=1 , 24bit=2 , 32bit=3]"
if %errorlevel%==1 set bit=-acodec pcm_s16le
if %errorlevel%==2 set bit=-acodec pcm_s24le
if %errorlevel%==1 set bit=-acodec pcm_s32le

choice /c 480n /m "44.1か48かそのままか自由入力か"
if %errorlevel%==1 set ar= -ar 44100
if %errorlevel%==2 set ar= -ar 48000
if %errorlevel%==4 set /P ar= -ar XXXXXで入力してください＞

choice /c ns0 /m "モノラルかステレオかそのままか"
if %errorlevel%==1 set ac= -ac 1
if %errorlevel%==2 set ac= -ac 2

:skip
if not "%~2"=="" goto 2ormore

:roop
cd /d "%~dp1"
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i "%~1" -vn %ac%%ar% %bit% -f wav "%~dpn1 ffmpeg.wav"
shift
if not "%~1"=="" goto roop
exit

:2ormore
cd /d "%~dp1"
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
If not exist ffmpeg  mkdir ffmpeg
ffmpeg -hide_banner -i "%~1" -vn %ac%%ar% %bit% -f wav "ffmpeg\%~n1.wav"
shift
if not "%~1"=="" goto 2ormore
pause
exit


:show_help
echo.
echo [概要]
echo   音声ファイルを WAV に変換します。量子化ビット数、サンプリング周波数、チャンネル数を選択可能。
echo.
echo [使い方]
echo   %~nx0 ^<file_or_folder^> [more files...]
echo.
echo [出力]
echo   同階層に「^<元名^> ffmpeg.wav」または「ffmpeg\\^<元名^>.wav」を作成します。
echo.
echo [補足]
echo   ・ffmpeg が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
