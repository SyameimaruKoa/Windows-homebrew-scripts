@echo off
chcp 932
echo 動画.%~nx1
echo 音声.%~nx2
echo 動画.%~nx3
echo 音声.%~nx4
echo 動画.%~nx5
echo 音声.%~nx6
echo 動画.%~nx7
echo 音声.%~nx8

choice /m "拡張子をMP4にする場合はNを、MKVにする場合はYを押してください"
if %errorlevel%==1 set extension=mkv
if %errorlevel%==2 set extension=mp4

if "%~3"=="" goto 1combining
if "%~4"=="" (
set stream=1half
goto Streamname
)
if "%~5"=="" (
set stream=2
goto Streamname
)
if "%~7"=="" (
set stream=3
goto Streamname
)
if "%~9"=="" (
set stream=4
goto Streamname
)
echo 5つ以上のマルチトラック化は対応させてません。

:Streamname
echo 「1グループ目」変更するストリーム名を入力してください。
set change1=
set /P change1=

echo 「2グループ目」変更するストリーム名を入力してください。
set change2=
set /P change2=
if %stream%==1half goto 1halfcombining
if %stream%==2 goto 2combining

echo 「3グループ目」変更するストリーム名を入力してください。
set change3=
set /P change3=
if %stream%==3 goto 3combining

echo 「4グループ目」変更するストリーム名を入力してください。
set change4=
set /P change4=
if %stream%==4 goto 4combining
exit

:1combining
echo 動画と音声を結合します。
echo ──────────────────────────────
echo 動画(1).%~n1
echo 音声(2).%~n2
choice /c 012 /n /m どのファイルからプロパティをコピーしますか？(しない場合は0を入力)
if %errorlevel%==1 set properties=no
if %errorlevel%==2 set properties=%~n1
if %errorlevel%==3 set properties=%~n2
ffmpeg -hide_banner -i %1 -i %2 -c copy -map 0:v:0 -map 1:a:0 "%~dpn1 (combining).%extension%"
if "%properties%"=="no" (
goto exit
) else (
exiftool -api largefilesupport=1 -tagsfromfile "%properties%" -all:all -overwrite_original "%~dpn1 (combining).%extension%"
)
goto exit

:1halfcombining
echo 2つの動画をマルチトラック化します。
echo ──────────────────────────────
echo 1.%~n1
echo 3.%~n3
choice /c 013 /n /m どのファイルからプロパティをコピーしますか？(しない場合は0を入力)
if %errorlevel%==1 set properties=no
if %errorlevel%==2 set properties=%~1
if %errorlevel%==3 set properties=%~3
ffmpeg -hide_banner -i %1 -i %2 -i %3 -c copy ^
-map 0:v:0 ^
-map 1:a:0 ^
-map 2:v:0 ^
-metadata:s:v:0 title="%change1%" ^
-metadata:s:v:1 title="%change2%" ^
-metadata:s:a:0 title="%change1%" ^
"%~dpn1 Multitrack.%extension%"
if "%properties%"=="no" (
goto exit
) else (
exiftool -api largefilesupport=1 -tagsfromfile "%properties%" -all:all -overwrite_original "%~dpn1 Multitrack.%extension%"
)
goto exit

:2combining
echo 2つの動画をマルチトラック化します。
echo ──────────────────────────────
echo 1.%~n1
echo 3.%~n3
choice /c 013 /n /m どのファイルからプロパティをコピーしますか？(しない場合は0を入力)
if %errorlevel%==1 set properties=no
if %errorlevel%==2 set properties=%~1
if %errorlevel%==3 set properties=%~3
ffmpeg -hide_banner -i %1 -i %2 -i %3 -i %4 -c copy ^
-map 0:v:0 ^
-map 1:a:0 ^
-map 2:v:0 ^
-map 3:a:0 ^
-metadata:s:v:0 title="%change1%" ^
-metadata:s:v:1 title="%change2%" ^
-metadata:s:a:0 title="%change1%" ^
-metadata:s:a:1 title="%change2%" ^
"%~dpn1 Multitrack.%extension%"
if "%properties%"=="no" (
goto exit
) else (
exiftool -api largefilesupport=1 -tagsfromfile "%properties%" -all:all -overwrite_original "%~dpn1 Multitrack.%extension%"
)
goto exit

:3combining
echo 3つの動画をマルチトラック化します。
echo ──────────────────────────────
echo 1.%~n1
echo 3.%~n3
echo 5.%~n5
choice /c 0135 /n /m どのファイルからプロパティをコピーしますか？(しない場合は0を入力)
if %errorlevel%==1 set properties=no
if %errorlevel%==2 set properties=%~1
if %errorlevel%==3 set properties=%~3
if %errorlevel%==4 set properties=%~5
ffmpeg -hide_banner -i %1 -i %2 -i %3 -i %4 -i %5 -i %6 -c copy ^
-map 0:v:0 ^
-map 1:a:0 ^
-map 2:v:0 ^
-map 3:a:0 ^
-map 4:v:0 ^
-map 5:a:0 ^
-metadata:s:v:0 title="%change1%" ^
-metadata:s:v:1 title="%change2%" ^
-metadata:s:v:2 title="%change3%" ^
-metadata:s:a:0 title="%change1%" ^
-metadata:s:a:1 title="%change2%" ^
-metadata:s:a:2 title="%change3%" ^
"%~dpn1 Multitrack.%extension%"
if "%properties%"=="no" (
goto exit
) else (
exiftool -api largefilesupport=1 -tagsfromfile "%properties%" -all:all -overwrite_original "%~dpn1 Multitrack.%extension%"
)
goto exit

:4combining
echo 4つの動画をマルチトラック化します。
echo ──────────────────────────────
echo 1.%~n1
echo 3.%~n3
echo 5.%~n5
echo 7.%~n7
choice /c 01357 /n /m どのファイルからプロパティをコピーしますか？(しない場合は0を入力)
if %errorlevel%==1 set properties=no
if %errorlevel%==2 set properties=%~1
if %errorlevel%==3 set properties=%~3
if %errorlevel%==4 set properties=%~5
if %errorlevel%==5 set properties=%~7
ffmpeg -hide_banner -i %1 -i %2 -i %3 -i %4 -i %5 -i %6 -i %7 -i %8 -c copy ^
-map 0:v:0 ^
-map 1:a:0 ^
-map 2:v:0 ^
-map 3:a:0 ^
-map 4:v:0 ^
-map 5:a:0 ^
-map 6:v:0 ^
-map 7:a:0 ^
-metadata:s:v:0 title="%change1%" ^
-metadata:s:v:1 title="%change2%" ^
-metadata:s:v:2 title="%change3%" ^
-metadata:s:v:3 title="%change4%" ^
-metadata:s:a:0 title="%change1%" ^
-metadata:s:a:1 title="%change2%" ^
-metadata:s:a:2 title="%change3%" ^
-metadata:s:a:3 title="%change4%" ^
"%~dpn1 Multitrack.%extension%"
if "%properties%"=="no" (
goto exit
) else (
exiftool -api largefilesupport=1 -tagsfromfile "%properties%" -all:all -overwrite_original "%~dpn1 Multitrack.%extension%"
)
:exit
if %errorlevel%==0 (
echo 成功しました。
) else echo 失敗しました。
pause
exit