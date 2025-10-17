@echo off
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
