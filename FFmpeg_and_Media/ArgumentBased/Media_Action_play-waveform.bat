cd /d %TEMP%
ffmpeg -hide_banner -i %1 -vn -f wav "%~n1 ffmpeg tmp.wav"
call "C:\Users\kouki\OneDrive\PortableApps\WS151\WS.EXE" "%TEMP%\%~n1 ffmpeg tmp.wav"
del "%~n1 ffmpeg tmp.wav"
exit