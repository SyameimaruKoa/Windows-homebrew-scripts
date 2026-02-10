@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932
if "%~x1"=="" goto folder

:file
cd /D "%~dp1"
move "%~1" ..\
if %errorlevel%==0 rmdir "%~dp1" > nul
shift
if not "%~1"=="" goto file
timeout /nobreak 1
exit

:folder
cd /D "%~1"
for /r %%i in (*) do move "%%i" ..\
cd ../
rmdir "%~1" > nul
shift
if not "%~1"=="" goto folder
timeout /nobreak 1
exit

:show_help
echo.
echo [概要]
echo   指定したファイルまたはフォルダの中身を一階層上(親フォルダ)へ移動します。
echo.
echo [使い方]
echo   %~nx0 ^<file_or_folder1^> ^<file_or_folder2^> ...
echo.
echo [注意]
echo   - フォルダ指定時は中身のみを移動し、空になったフォルダは削除します。
echo   - 同名衝突があると移動できない場合があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b