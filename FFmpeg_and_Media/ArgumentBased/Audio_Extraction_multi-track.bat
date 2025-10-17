@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
ffprobe -hide_banner %1
%~d1
cd "%~dp1"
If not exist ffmpeg  mkdir ffmpeg
choice /c 12345678 /m 総トラック数を入力してください(最大8トラック)
if %errorlevel%==1 (
echo 分離は不要です。
goto exit
)

if %errorlevel%==2 goto 2Truck
if %errorlevel%==3 goto 3Truck
if %errorlevel%==4 goto 4Truck
if %errorlevel%==5 goto 5Truck
if %errorlevel%==6 goto 6Truck
if %errorlevel%==7 goto 7Truck
if %errorlevel%==8 goto 8Truck
exit

:2Truck

:show_help
echo.
echo [概要]
echo   入力メディアの音声トラックを、指定した本数に応じて個別ファイルに分離します（最大8）。
echo.
echo [使い方]
echo   %~nx0 ^<media_file^>
echo.
echo [出力]
echo   同階層の ffmpeg\ フォルダに TrackN という名前で書き出します。
echo.
echo [前提]
echo   ・ffmpeg と ffprobe が PATH に通っていること。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
echo 合計2個のトラックを分離します
:roop
%~d1
cd "%~dp1"
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i %1 ^
-map 0:0 -c copy "ffmpeg\%~n1 Track1%~x1" ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2%~x1"
shift
if not "%~1"=="" goto roop
goto exit
 
:3Truck
echo 合計3個のトラックを分離します
ffmpeg -hide_banner -i %1 ^
-map 0:0 -c copy "ffmpeg\%~n1 Track1%~x1" ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2%~x1" ^
-map 0:2 -c copy "ffmpeg\%~n1 Track3%~x1"
goto exit

:4Truck
echo 合計4個のトラックを分離します
ffmpeg -hide_banner -i %1 ^
-map 0:0 -c copy "ffmpeg\%~n1 Track1%~x1" ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2%~x1" ^
-map 0:2 -c copy "ffmpeg\%~n1 Track3%~x1" ^
-map 0:3 -c copy "ffmpeg\%~n1 Track4%~x1"
goto exit

:5Truck
echo 合計5個のトラックを分離します
ffmpeg -hide_banner -i %1 ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2.dts" ^
-map 0:2 -c copy "ffmpeg\%~n1 Track3.dts" 
goto exit

:6Truck
echo 合計6個のトラックを分離します
ffmpeg -hide_banner -i %1 ^
-map 0:0 -c copy "ffmpeg\%~n1 Track1%~x1" ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2%~x1" ^
-map 0:2 -c copy "ffmpeg\%~n1 Track3%~x1" ^
-map 0:3 -c copy "ffmpeg\%~n1 Track4%~x1" ^
-map 0:4 -c copy "ffmpeg\%~n1 Track5%~x1" ^
-map 0:5 -c copy "ffmpeg\%~n1 Track6%~x1"
goto exit

:7Truck
echo 合計7個のトラックを分離します
ffmpeg -hide_banner -i %1 ^
-map 0:0 -c copy "ffmpeg\%~n1 Track1%~x1" ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2%~x1" ^
-map 0:2 -c copy "ffmpeg\%~n1 Track3%~x1" ^
-map 0:3 -c copy "ffmpeg\%~n1 Track4%~x1" ^
-map 0:4 -c copy "ffmpeg\%~n1 Track5%~x1" ^
-map 0:5 -c copy "ffmpeg\%~n1 Track6%~x1" ^
-map 0:6 -c copy "ffmpeg\%~n1 Track7%~x1"
goto exit

:8Truck
echo 合計8個のトラックを分離します
ffmpeg -hide_banner -i %1 ^
-map 0:0 -c copy "ffmpeg\%~n1 Track1%~x1" ^
-map 0:1 -c copy "ffmpeg\%~n1 Track2%~x1" ^
-map 0:2 -c copy "ffmpeg\%~n1 Track3%~x1" ^
-map 0:3 -c copy "ffmpeg\%~n1 Track4%~x1" ^
-map 0:4 -c copy "ffmpeg\%~n1 Track5%~x1" ^
-map 0:5 -c copy "ffmpeg\%~n1 Track6%~x1" ^
-map 0:6 -c copy "ffmpeg\%~n1 Track7%~x1" ^
-map 0:7 -c copy "ffmpeg\%~n1 Track8%~x1"

:exit
exiftool -api largefilesupport=1 -tagsfromfile %1 -all:all -overwrite_original "ffmpeg\%~n1 Track1%~x1"
echo マルチトラックを分離しました。
if %errorlevel%==1 (
pause
) else timeout /nobreak 3
exit