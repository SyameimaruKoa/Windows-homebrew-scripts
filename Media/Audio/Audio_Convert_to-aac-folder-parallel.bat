@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932

echo aac-hcを使う場合は1
echo aac-heを使う場合は2
echo alac  を使う場合は3
choice /c 123
if %errorlevel%==1 set encoder=
if %errorlevel%==2 set encoder= --he
if %errorlevel%==3 set encoder= -A

choice /m "他を指定しますか？"
set V=
if %errorlevel%==2 goto parallelrun
echo 引数を入力してください。最後にスペースを入れてください
echo TVBR	-V	品質指定の数
echo CVBR	-v	目標のビットレート
echo ABR	-a	目標のビットレート
echo CBR	-c	目標のビットレート
echo.
echo TVBRの使用可能品質
echo 0 9 18 27 36 45 54 63 73 82 91 100 109 118 127
set /P V=
:parallelrun
start call "%~dp0Audio_Convert_to-aac-parallel.bat" %1
if not "%~2"=="" start call "%~dp0Audio_Convert_to-aac-parallel.bat" %2
if not "%~3"=="" start call "%~dp0Audio_Convert_to-aac-parallel.bat" %3
if not "%~4"=="" start call "%~dp0Audio_Convert_to-aac-parallel.bat" %4
if not "%~5"=="" start call "%~dp0Audio_Convert_to-aac-parallel.bat" %5
exit /b

:show_help
echo.
echo [概要]
echo   最大5つまでのフォルダを並列に処理し、それぞれの配下WAVをAAC/ALACに変換します。
echo   各ワーカーとして同階層の "Audio_Convert_to-aac-parallel.bat" を呼び出します。
echo.
echo [使い方]
echo   %~nx0 ^<folder1^> [folder2] [folder3] [folder4] [folder5]
echo.
echo [補足]
echo   ・qaac64 が PATH に通っている必要があります。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b