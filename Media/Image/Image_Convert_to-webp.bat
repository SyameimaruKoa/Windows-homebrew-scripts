@echo off
chcp 932 >nul
rem 下にヘルプがあるのじゃ

if "%~1"=="" goto show_help
if "%~1"=="-h" goto show_help
if "%~1"=="--help" goto show_help

set "TARGET_DIR=%~1"
if not exist "%TARGET_DIR%\" (
    echo 指定されたパスはフォルダではないか、存在しないのじゃ。
    pause
    exit /b 1
)

for /R "%TARGET_DIR%" %%I in (*.png) do (
    echo 変換中: "%%I"
    nconvert -out webp -q -1 -keep_exif -keep_iptc -keep_icc -keep_xmp -keepfiledate "%%I"
    if exist "%%~dpnI.webp" (
        del "%%I"
    ) else (
        echo 変換に失敗したようじゃ: "%%I"
    )
)

echo すべての処理が終わったのじゃ。
pause
exit /b 0

:show_help
echo ==================================================
echo nconvertを利用したPNGからロスレスWebPへの変換バッチ
echo ==================================================
echo.
echo [使い方]
echo このバッチファイルに対象のフォルダをドラッグ＆ドロップするのじゃ。
echo または、コマンドプロンプトからフォルダパスを引数として渡すのじゃ。
echo.
echo [オプション]
echo -h, --help    このヘルプを表示するのじゃ。
echo.
echo [動作]
echo ・指定されたフォルダ内のすべてのPNGファイルを再帰的にWebPに変換する。
echo ・nconvertを使ってロスレス（-q -1）で変換し、メタデータや更新日時を引き継ぐ。
echo ・変換が無事に完了したことを確認してから、元のPNGファイルを削除するのじゃ。
echo ・フォルダ構成はそのまま維持されるのじゃ。
echo.
pause
exit /b 0
