@echo off
chcp 932 >nul
rem 下にヘルプがあるのじゃ

rem XnView MPのインストール先にあるnconvert.exeをフルパスで指定するのじゃ
set "NCONVERT_EXE=C:\Users\kouki\OneDrive\CUIApplication\NConvert\nconvert.exe"

if "%~1"=="" goto show_help
if "%~1"=="-h" goto show_help
if "%~1"=="--help" goto show_help

set "TARGET_DIR=%~1"
if not exist "%TARGET_DIR%\" (
    echo 指定されたパスはフォルダではないか、存在しないのじゃ。
    pause
    exit /b 1
)

if not exist "%NCONVERT_EXE%" (
    echo エラー: nconvert.exe が見つからんぞ！
    echo バッチファイル内の NCONVERT_EXE のパスを自分の環境に合わせて書き直すのじゃ！
    pause
    exit /b 1
)

echo 実行場所: %CD%
echo 対象フォルダ: %TARGET_DIR%
echo WebPに変換中じゃ。しばらくお待ちくだされ...
"%NCONVERT_EXE%" -v -out webp -q -1 -keep_icc -keepfiledate -D -recurse "%TARGET_DIR%\*.png"

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
echo ・nconvertの-recurse機能で一括入力するため、処理が非常に高速じゃ。
echo ・-vで各ファイルの詳細情報（解像度等）を出力し、-Dで変換後の元ファイルを自動削除するのじゃ。
echo ・XnView MPのnconvertを直接呼び出し、確実にWebPプラグインを読み込ませるのじゃ。
echo ・nconvertを使ってロスレス（-q -1）で変換し、ICCと更新日時を引き継ぐ。
echo ・フォルダ構成はそのまま維持されるのじゃ。
echo.
pause
exit /b 0