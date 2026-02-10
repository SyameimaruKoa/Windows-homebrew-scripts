@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932

rem 対象フォルダを指定
set "targetFolder=%~1"

rem フォルダの存在有無を確認
if not exist "%targetFolder%" (
  echo 対象フォルダが存在しないため、処理を終了します。
  echo.
  pause
  exit
)

rem フォルダ(サブフォルダ含む)を取得するコマンドを作成
set cmd="dir %targetFolder% /ad /b /s | sort /r"

rem 空フォルダを削除 ※空でないフォルダの削除は失敗する
for /f "delims=" %%a in ('%cmd%') do (
  rd /q "%%a" 2> NUL
)

echo 空フォルダを削除しました。
echo.

pause
exit

:show_help
echo.
echo [概要]
echo  指定フォルダ配下の空ディレクトリを再帰的に削除します。
echo.
echo [使い方]
echo  %~nx0 ^<folder^>
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
