@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if "%comparison%"=="yes" goto 2ormore

chcp 932
if "%~x1"=="" goto folder
rem 動画カット
timeout /nobreak 1 > nul
choice /m 動画をカットしますか？
if %errorlevel%==1 set cut=yes


if not "%~2"=="" goto 2ormore

:roop
%~d1
cd "%~dp1"
cls
rem 動画カット
set cutinfo=
if "%cut%"=="yes" goto cut1
:cutbach1
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner %cutinfo%-i "%~1" -vn %cutinfo2%-strict experimental "%~dpn1 ffmpeg.flac"
shift
if not "%~1"=="" goto roop
pause
exit

:2ormore
%~d1
cd "%~dp1"
cls
rem 動画カット
set cutinfo=
if "%cut%"=="yes" goto cut2
:cutbach2
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
If not exist ffmpeg  mkdir ffmpeg
ffmpeg -hide_banner %cutinfo%-i "%~1" -vn %cutinfo2%-strict experimental "ffmpeg\%~n1.flac"

rem 比較バッチ用
if "%comparison%"=="yes" exit /b

shift
if not "%~1"=="" goto 2ormore
pause
exit

:folder
%~d1
cd %1
If not exist ffmpeg  mkdir ffmpeg
for /r %%i in (*.wav) do ffmpeg -hide_banner -i "%%i" -vn -strict experimental "ffmpeg\%%~ni.flac"
timeout /nobreak 10
call C:\Users\kouki\OneDrive\CUIApplication\notify.bat flac_end
pause
exit


:cut1
start "" "C:\Users\kouki\OneDrive\PortableApps\LosslessCutPortable\LosslessCutPortable.exe" %1 > nul
echo LosslessCutを使いカットしたいタイムコードを特定してください
echo (エンドは実際には1フレ後ろになります)
echo （書き方 00:00:00.000）
echo 開始位置
set cutstart=
set /P cutstart=
timeout /nobreak 1 > nul
echo 終了位置
set cutend=
set /P cutend=
set cutinfo=-ss %cutstart% -to %cutend% 
set cutinfo2=-ss 0 
goto cutbach1
exit

:cut2
start "" "C:\Users\kouki\OneDrive\PortableApps\LosslessCutPortable\LosslessCutPortable.exe" %1 > nul
echo LosslessCutを使いカットしたいタイムコードを特定してください
echo (エンドは実際には1フレ後ろになります)
echo （書き方 00:00:00.000）
echo 開始位置
set cutstart=
set /P cutstart=
timeout /nobreak 1 > nul
echo 終了位置
set cutend=
set /P cutend=
set cutinfo=-ss %cutstart% -to %cutend% 
set cutinfo2=-ss 0 
goto cutbach2
exit


:show_help
echo.
echo [概要]
echo   各種メディアから音声を抽出/変換して FLAC に出力します。
echo   1つ以上のファイル、またはフォルダパスを引数に指定して使います。
echo.
echo [使い方]
echo   %~nx0 ^<file_or_folder^> [more files...]
echo     例) %~nx0 song.wav
echo     例) %~nx0 video.mp4
echo     例) %~nx0 "C:\\path\\to\\folder"
echo.
echo [出力]
echo   同階層に「^<元名^> ffmpeg.flac」または「ffmpeg\\^<元名^>.flac」を作成します。
echo.
echo [補足]
echo   ・オプションでLosslessCutを起動し、指定範囲のみを切り出せます。
echo   ・ffmpeg が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b