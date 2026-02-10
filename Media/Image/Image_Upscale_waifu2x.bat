@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
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
echo waifu2x-ncnn-vulkan -i "%1" -o "%~dpn1_waifu2x.png" -n 1 %scale% -f png
echo ────────────────────────────────────────────────────────────────────────────────────────────────
waifu2x-ncnn-vulkan -i "%1" -o "%~dpn1_waifu2x.png" -n 1 %scale% -f png
if %errorlevel%==1 pause
exit

:show_help
echo.
echo [概要]
echo   waifu2x-ncnn-vulkan を使って、2倍スケールまたはノイズ除去のみを行います。
echo.
echo [使い方]
echo   %~nx0 ^<image_file^>
echo.
echo [出力]
echo   同階層に ^<元名^>_waifu2x.png を作成します。
echo.
echo [前提]
echo   ・waifu2x-ncnn-vulkan が PATH に通っていること。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b