@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
setlocal enabledelayedexpansion

set "linkpath="
echo シンボリックリンクを作成する先のフォルダパスを入力してください（末尾の\は不要）
set /P linkpath=>
if not exist "%linkpath%\" (
  echo 入力されたフォルダが見つかりません: "%linkpath%"
  pause
  exit /b 1
)

:roop
if "%~x1"=="" (
  mklink /D "%linkpath%\%~nx1" %1
  ) else (
  mklink "%linkpath%\%~nx1" %1
)
shift
if not "%~1"=="" goto roop
pause
exit

:show_help
echo.
echo [概要]
echo  ドラッグしたファイル/フォルダのシンボリックリンクを指定フォルダに作成します。
echo.
echo [使い方]
echo  %~nx0 ^<file_or_folder1^> [file_or_folder2 ...]
echo.
echo [注意]
echo  ・管理者権限が必要な場合があります。
echo  ・フォルダは /D を付けて作成します。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
