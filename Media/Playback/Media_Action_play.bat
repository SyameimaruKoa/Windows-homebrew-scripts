@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932 > nul

echo 再生するファイル: %~nx1
echo -------------------------------------------------
echo 適用したいフィルターを書き入れるのじゃ。
echo 適用しない場合は、何も書かずにEnterを押すがよい。
echo.
echo 例 (音声): volume=2.0
echo 例 (動画): eq=gamma=1.5,vflip
echo -------------------------------------------------
echo.

set AF_OPTION=
set /p USER_AF="音声フィルター (-af) > "
if not "%USER_AF%"=="" set AF_OPTION=-af "%USER_AF%"

set VF_OPTION=
set /p USER_VF="動画フィルター (-vf) > "
if not "%USER_VF%"=="" set VF_OPTION=-vf "%USER_VF%"

echo.
echo -------------------------------------------------
echo これから再生を開始する。心して観るのじゃ！
echo.

ffplay -hide_banner -i "%~1" %AF_OPTION% %VF_OPTION%

goto :eof

:show_help
echo.
echo [概要]
echo   ffplay でメディアを再生します。任意の -af / -vf を対話入力で適用可能。
echo.
echo [使い方]
echo   %~nx0 ^<media_file^>
echo.
echo [補足]
echo   ・ffplay が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b