@echo off
chcp 932
%~d1
cd "%~dp1"
If not exist ffmpeg  mkdir ffmpeg
If not exist upconv  mkdir upconv
If not exist end  mkdir end
rem 元ファイルをD&Dして、そのファイルからメタデータを取って、高音質化したwavをflacにして、変換したflacにメタデータを入れて、元ファイルとメタデータファイルとwavを削除する
echo FLACは1
echo WAVは2
echo AACは3
choice /c 123
if %errorlevel%==1 goto flacmode
if %errorlevel%==2 goto wavmode
if %errorlevel%==3 goto accmode
exit

:accmode
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i %1 -f ffmetadata "upconv\%~n1.txt"
ffmpeg -hide_banner -i %1 -an -c:v copy "upconv\%~n1.png"
qaac64 "upconv\%~n1.wav" -o "upconv\%~n1 qaac.m4a"
ffmpeg -hide_banner -i "upconv\%~n1 qaac.m4a" -i "upconv\%~n1.txt" -i "upconv\%~n1.png" -map 0:a -map 2:v -disposition:1 attached_pic -map_metadata 1 -c copy "end\%~n1.m4a"
if %errorlevel%==1 ffmpeg -hide_banner -i "upconv\%~n1 qaac.m4a" -i "upconv\%~n1.txt" -disposition:1 attached_pic -map_metadata 1 -c copy "end\%~n1.m4a"
if not %errorlevel%==1 (
del "upconv\%~n1.txt"
del "upconv\%~n1.png"
del "ffmpeg\%~n1.wav"
del "upconv\%~n1 qaac.m4a"
del %1
) else (
echo 何らかのファイルが不足しています。
pause
)
shift
if not "%~1"=="" goto accmode
timeout /nobreak 10
call C:\Users\kouki\OneDrive\CUIApplication\notify.bat upconv_end
pause
exit

:wavmode
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i %1 -f ffmetadata "upconv\%~n1.txt"
ffmpeg -hide_banner -i "upconv\%~n1.wav" -i "upconv\%~n1.txt" -map 0:a -disposition:1 attached_pic -map_metadata 1 -codec copy "end\%~n1.wav"
if %errorlevel%==1 ffmpeg -hide_banner -i "upconv\%~n1 qaac.m4a" -i "upconv\%~n1.txt" -disposition:1 attached_pic -map_metadata 1 -codec copy "end\%~n1.wav"
if not %errorlevel%==1 (
del "upconv\%~n1.txt"
del "upconv\%~n1.wav"
del "ffmpeg\%~n1.wav"
del %1
) else (
echo 何らかのファイルが不足しています。
pause
)

shift
if not "%~1"=="" goto wavmode
timeout /nobreak 10
call C:\Users\kouki\OneDrive\CUIApplication\notify.bat upconv_end
pause
exit

:flacmode
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
ffmpeg -hide_banner -i %1 -f ffmetadata "upconv\%~n1.txt"
ffmpeg -hide_banner -i %1 -an -c:v copy "upconv\%~n1.png"
ffmpeg -hide_banner -i "upconv\%~n1.wav" -i "upconv\%~n1.txt" -i "upconv\%~n1.png" -map 0:a -map 2:v -disposition:1 attached_pic -map_metadata 1 "end\%~n1.flac"
if %errorlevel%==1 ffmpeg -hide_banner -i "upconv\%~n1 qaac.m4a" -i "upconv\%~n1.txt" -disposition:1 attached_pic -map_metadata 1 "end\%~n1.flac"
if not %errorlevel%==1 (
del "upconv\%~n1.txt"
del "upconv\%~n1.png"
del "ffmpeg\%~n1.wav"
del "upconv\%~n1.flac"
del %1
) else (
echo 何らかのファイルが不足しています。
pause
)
shift
if not "%~1"=="" goto flacmode
timeout /nobreak 10
call C:\Users\kouki\OneDrive\CUIApplication\notify.bat upconv_end
pause
exit