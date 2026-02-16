@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help で表示）
rem 未引数の場合は対話モードで実行します

chcp 932 >nul
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

setlocal enabledelayedexpansion

set "linkpath="
echo シンボリックリンクを作成する先のフォルダパスを入力してください（末尾の\は不要）
set /P linkpath=>
if not exist "%linkpath%\" (
  echo 入力されたフォルダが見つかりません: "%linkpath%"
  pause
  exit /b 1
)

rem 引数がある場合は従来のループ処理へ
if not "%~1"=="" goto :roop

rem --- 引数なしの場合の対話モード ---
:interactive_loop
echo.
echo リンク元のファイルまたはフォルダのフルパスを入力してください（空欄で終了）
set "target="
set /P target=>

rem 空入力で終了
if "!target!"=="" exit /b

rem 入力に含まれる引用符を除去（ドラッグ＆ドロップやコピペ対策）
set "target=!target:"=!"

if not exist "!target!" (
  echo 存在しません: "!target!"
  goto :interactive_loop
)

rem オリジナルのロジック（拡張子の有無）でディレクトリ判定を行う
rem 引用符を除去した変数に対してループを回して属性を取得
for %%I in ("!target!") do (
  if "%%~xI"=="" (
    mklink /D "%linkpath%\%%~nxI" "%%~I"
    ) else (
    mklink "%linkpath%\%%~nxI" "%%~I"
  )
)
goto :interactive_loop

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
echo  引数なしで起動した場合は、対話モードでパスを入力して作成できます。
echo.
echo [使い方]
echo  ドラッグ＆ドロップ: %~nx0 ^<file_or_folder1^> [file_or_folder2 ...]
echo  手動入力モード  : %~nx0 （引数なし）
echo.
echo [注意]
echo  ・管理者権限が必要な場合があります。
echo  ・フォルダは /D を付けて作成します（拡張子がないものをフォルダとみなします）。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
