@echo off
chcp 932
%~d1
cd "%~dp0"
:roop
set audio1=
set audio2=
set audio3=
set audio4=
set audio5=
set audio6=
cls
set /a filecount=filecount+1
echo %filecount%個目のファイルを処理するよ
echo m2ts化する動画ファイル（%~nx1）
del "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo MUXOPT --no-pcr-on-video-pid --new-audio-pes --vbr  --vbv-len=500 > "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo V_MPEG4/ISO/AVC, "%~1", insertSEI, contSPS, track=1, lang=und >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
choice /c 123456 /m オーディオファイルを何個入れる？
if %errorlevel%==1 set multiaudio=1file
if %errorlevel%==2 set multiaudio=2file
if %errorlevel%==3 set multiaudio=3file
if %errorlevel%==4 set multiaudio=4file
if %errorlevel%==5 set multiaudio=5file
if %errorlevel%==6 set multiaudio=6file
echo ダブルクオーテーションは入力しないでください

if not %multiaudio%==1 goto MultiAudio
echo オーディオファイルを投げてください
set /P audio1=
goto audioset
exit

:MultiAudio
echo 1つ目のオーディオファイルを投げてください
set /P audio1=
echo 2つ目のオーディオファイルを投げてください
set /P audio2=
if %multiaudio%==2file goto audioset
echo 3つ目のオーディオファイルを投げてください
set /P audio3=
if %multiaudio%==3file goto audioset
echo 4つ目のオーディオファイルを投げてください
set /P audio4=
if %multiaudio%==4file goto audioset
echo 5つ目のオーディオファイルを投げてください
set /P audio5=
if %multiaudio%==5file goto audioset
echo 6つ目のオーディオファイルを投げてください
set /P audio6=
if %multiaudio%==6file goto audioset
exit
:audioset
if not "%audio1%"=="" echo A_AAC, "%audio1%", track=1, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
if not "%audio2%"=="" echo A_AAC, "%audio2%", track=1, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
if not "%audio3%"=="" echo A_AAC, "%audio3%", track=1, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
if not "%audio4%"=="" echo A_AAC, "%audio4%", track=1, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
if not "%audio5%"=="" echo A_AAC, "%audio5%", track=1, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
if not "%audio6%"=="" echo A_AAC, "%audio6%", track=1, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
choice /c 12 /m 字幕は何個入れますか？
if %errorlevel%==1 set text=1file

if not %text%==1file goto TEXT
echo 字幕ファイルを投げてください
set /P text1=
goto textset
exit
:TEXT
echo 1つ目の字幕ファイルを投げてください
set /P text1=
echo 2つ目の字幕ファイルを投げてください
set /P text2=

:textset
if not "%text1%"=="" echo S_TEXT/UTF8, "%text1%",font-name="Noto Serif JP Light",font-size=60,font-color=0xff55ff7f,bottom-offset=24,font-border=5,text-align=center,video-width=1920,video-height=1080,fps=24, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
if not "%text2%"=="" echo S_TEXT/UTF8, "%text2%",font-name="Noto Serif JP Light",font-size=60,font-color=0xff55ff7f,bottom-offset=24,font-border=5,text-align=center,video-width=1920,video-height=1080,fps=24, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"

"C:\Users\kouki\Documents\tsMuxeR_2.6.12\tsMuxeR.exe" "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta" "C:\Users\kouki\Desktop\BD\%~n1.m2ts"
shift
if not "%~1"=="" goto roop
timeout /nobreak 3
exit /b