@echo off
chcp 932
%~d1
cd "%~dp1"
choice /m 解像度を2倍にあげますか？
if %errorlevel%==1 (
echo 解像度を2倍にあげます。(品質はwaifu2x-caffeのCUnetの方が上です)
set scale=-s 2
) else (
echo ノイズ除去のみ行います(恐らくwaifu2x-caffeと品質は同じです)
set scale=-s 1
)
echo waifu2x-ncnn-vulkan -i %1 -o "%~dpn1_waifu2x.png" -n 1 %scale% -f png
echo ────────────────────────────────────────────────────────────────────────────────────────────────
waifu2x-ncnn-vulkan -i %1 -o "%~dpn1_waifu2x.png" -n 1 %scale% -f png
if %errorlevel%==1 pause
exit