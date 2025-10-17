@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 65001
echo Gboard←→G日本語入力形式変換するにはY
echo それ以外の場合はN
choice /n
if %errorlevel%==1 goto gbjn
if %errorlevel%==2 goto input
exit

:input
echo びふぉー(全角＆特殊文字を使う場合は"ダブルクオーテーション"で囲ってください)
set /P BEFORE_STRING=
echo あふたー(全角＆特殊文字を使う場合は"ダブルクオーテーション"で囲ってください)
set /P AFTER_STRING=
goto start

:gbjn
echo "1.Gboard→G日本語入力"
echo "2.G日本語入力→Gboard"
choice /c 12
if %errorlevel%==1 (
set BEFORE_STRING=	ja-JP
set AFTER_STRING=	名詞	
)
if %errorlevel%==2 (
set BEFORE_STRING=	名詞	
set AFTER_STRING=	ja-JP
)

goto start

:start
setlocal enabledelayedexpansion
del "%~dpn1置換後%~x1"
for /f "delims=" %%a in (%1) do (
set line=%%a
echo !line:%BEFORE_STRING%=%AFTER_STRING%!>>"%~dpn1置換後%~x1"
)
pause
exit

:show_help
echo.
echo [概要]
echo   テキストファイル内の文字列を置換します。Gboard ^<^> Google日本語入力 の辞書形式相互変換にも対応。
echo.
echo [使い方]
echo   %~nx0 ^<target.txt^>
echo   対話で BEFORE/AFTER または Gboard/Google 日本語入力 の変換を選択します。
echo.
echo [出力]
echo   同じ場所に "^<元名^>置換後^<拡張子^>" を作成。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
