@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932 >nul

setlocal enabledelayedexpansion

set "TARGET=%~1"
if not defined TARGET (
    echo フォルダをD&Dしてほしいのじゃ。
    pause
    exit /b
)

cd /d "%TARGET%"

rem ファイルのみを対象にし、LastWriteTime をロケール非依存で取得して yyyy-MM に仕分け
for /f "delims=" %%F in ('dir /b /a:-d') do (
    set "FILE=%%F"
    for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "(Get-Item -LiteralPath '%CD%\!FILE!').LastWriteTime.ToString('yyyy-MM')"`) do (
        set "DESTFOLDER=%%T"
    )
    if not exist "!DESTFOLDER!" mkdir "!DESTFOLDER!"
    move "!FILE!" "!DESTFOLDER!\" >nul
)

echo 完了じゃ。
pause

:show_help
echo.
echo [概要]
echo   フォルダ内のファイルを更新日時の 年-月 フォルダに自動仕分けします。
echo.
echo [使い方]
echo   %~nx0 ^<target_folder^>
echo.
echo [出力]
echo   同じ場所に YYYY-MM のフォルダを作り、中へ move します。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
