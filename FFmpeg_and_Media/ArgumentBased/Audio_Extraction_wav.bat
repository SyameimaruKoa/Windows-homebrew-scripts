@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
if not "%~2"=="" goto 2ormore

:roop
%~d1
cd "%~dp1"
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i "%~1" -vn -c:a copy "%~dpn1 ffmpeg.wav"
shift
if not "%~1"=="" goto roop
pause
exit

:show_help
echo.
echo [概要]
echo   メディアから音声トラックを無変換で抽出し、WAVに保存します。
echo.
echo [使い方]
echo   %~nx0 ^<file1^> [file2 ...]
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

:2ormore
%~d1
cd "%~dp1"
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
If not exist ffmpeg  mkdir ffmpeg
ffmpeg -hide_banner -i "%~1" -vn -c:a copy "ffmpeg\%~n1.wav"
shift
if not "%~1"=="" goto 2ormore
pause
exit