@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
%~d1
cd "%~dp1"
:roop
If not exist 1st  mkdir 1st
If not exist 2nd  mkdir 2nd
If not exist 3rd  mkdir 3rd
If not exist 4th  mkdir 4th
move %1 1st\
move %2 2nd\
move %3 3rd\
move %4 4th\
shift
shift
shift
shift
if not "%~1"=="" goto roop
exit /b

:show_help
echo.
echo [概要]
echo   ドロップされたファイルを 1st/2nd/3rd/4th フォルダに順番に振り分けて移動します。
echo.
echo [使い方]
echo   %~nx0 ^<file1^> ^<file2^> ^<file3^> ^<file4^> [^<file5...^>]
echo.
echo [注意]
echo   既存の同名ファイルがあると移動に失敗することがあります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b