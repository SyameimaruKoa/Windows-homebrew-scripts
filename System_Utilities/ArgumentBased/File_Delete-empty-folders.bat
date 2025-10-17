@echo off
chcp 932

rem 対象フォルダを指定
set targetFolder=%1

rem フォルダの存在有無を確認
if not exist %targetFolder% (
    echo 対象フォルダが存在しないため、処理を終了します。
    echo.
    pause
    exit
)

rem フォルダ(サブフォルダ含む)を取得するコマンドを作成
set cmd="dir %targetFolder% /ad /b /s | sort /r"

rem 空フォルダを削除 ※空でないフォルダの削除は失敗する
for /f "delims=" %%a in ('%cmd%') do (
    rd /q %%a 2> NUL
)

echo 空フォルダを削除しました。
echo.

pause
exit