@echo off
chcp 932 > nul

if "%~1"=="" (
    echo ファイルをわっちの上にドラッグ＆ドロップするのじゃ！
    pause
    exit
)

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