@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
%~d1
cd %1
If not exist ..\qaac  mkdir ..\qaac
for /r %%i in (*.wav) do qaac64%encoder% "%%i" %ar%%V%-o "..\qaac\%%~ni.m4a"
@REM これは昔使ってたラインに通知飛ばす用 ： @REM これは昔使ってたラインに通知飛ばす用 ： call C:\Users\kouki\OneDrive\CUIApplication\notify.bat m4a_end
exit

:show_help
echo.
echo [概要]
echo   指定フォルダ配下の WAV を並列で AAC/ALAC に変換します（qaac64使用）。
echo.
echo [使い方]
echo   %~nx0 ^<folder^>
echo.
echo [出力]
echo   親フォルダに「qaac\\^<元名^>.m4a」を作成します。
echo.
echo [補足]
echo   ・qaac64 が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b