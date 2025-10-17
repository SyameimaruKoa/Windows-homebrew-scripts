@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
rem Shift-JISで保存するのじゃぞ！
chcp 932

rem ----------------------------------------------------------------
rem 設定変更可能な画像変換＆削除バッチ
rem ----------------------------------------------------------------

rem --- ▼▼▼ 設定はここを編集するのじゃ ▼▼▼ ---

rem ### 1. 出力形式とオプション ###
rem webpかtif、使いたい方の設定ブロックの行頭にある"rem "を【2行とも】消すのじゃ。
rem 使わない方は【2行とも】"rem "でコメントアウトしておくのを忘れるなよ。

rem --- WebP設定 ---
set "output_format=webp"
set "format_option=-quality 70"

rem --- TIF設定 ---
@REM set "output_format=tif"
@REM set "format_option=-compress JPEG -quality 85"

@REM set "format_option=-compress LZW"


rem ### 2. リサイズモード ###
rem 使いたいモードの行頭の"rem "を【1つだけ】消すのじゃ。他は必ず"rem "を付けておくのじゃぞ。
set "resize_mode=600x600>"  rem ■ 元画像が600pxより大きい場合だけ縮小（推奨）
@rem set "resize_mode=600x600"   rem ■ 常に600pxの枠に収まるようにリサイズ
@rem set "resize_mode=600x600!"  rem ■ 常に600px四方に変形してリサイズ（非推奨）
@rem set "resize_mode=600x"      rem ■ 横幅が常に600pxになるようにリサイズ
@rem set "resize_mode=x600"      rem ■ 高さが常に600pxになるようにリサイズ

rem --- ▲▲▲ 設定はここまでじゃ ▲▲▲ ---


rem (ここから下は、いじるでないぞ！)
rem ----------------------------------------------------------------

if "%~1"=="" goto :show_help
where magick >nul 2>nul || (
    echo "magick"コマンドが見つからん！ ImageMagickをインストールせい。
    pause
    exit /b
)

echo 処理を開始するぞ: %~nx1
echo 設定 - 形式: [%output_format%], リサイズ: [%resize_mode%]

set "output_file=%~dpn1.%output_format%"

magick "%~1" -resize "%resize_mode%" %format_option% "%output_file%"

if %errorlevel% equ 0 (
    echo 変換完了じゃ！: "%output_file%"
    echo 元ファイルを削除するぞ: %~nx1
    del "%~1"
    echo 削除完了じゃ。
) else (
    echo なんじゃと？ 変換中にエラーが発生したようじゃ！
    echo 元ファイルは削除しておらんから安心せい。
    pause
)

goto :eof

:show_help
echo.
echo [概要]
echo   画像ファイルを WebP(quality=70) もしくは TIF に変換します。必要に応じてリサイズ。
echo.
echo [使い方]
echo   %~nx0 ^<image_file^>
echo.
echo [前提]
echo   ・ImageMagick (magick.exe) が PATH に通っていること。
echo.
echo [補足]
echo   ・変換成功時は元ファイルを削除します。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b