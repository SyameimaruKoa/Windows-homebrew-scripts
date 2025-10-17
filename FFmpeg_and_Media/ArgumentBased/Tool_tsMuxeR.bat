@echo off
chcp 932
%~d1
cd "%~dp0"
:roop
cls
set /a filecount=filecount+1
echo %filecount%ŒÂ–Ú‚Ìƒtƒ@ƒCƒ‹‚ðˆ—‚·‚é‚æ
del "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo MUXOPT --no-pcr-on-video-pid --new-audio-pes --vbr  --vbv-len=500 > "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo V_MPEG4/ISO/AVC, "%~1", insertSEI, contSPS, track=1, lang=und >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
echo A_AAC, "%~1", track=2, lang=jpn >> "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta"
"C:\Users\kouki\Documents\tsMuxeR_2.6.12\tsMuxeR.exe" "C:\Users\kouki\Documents\tsMuxeR_2.6.12\auto.meta" "C:\Users\kouki\Desktop\BD\%~n1.m2ts"
shift
if not "%~1"=="" goto roop
timeout /nobreak 3
exit /b