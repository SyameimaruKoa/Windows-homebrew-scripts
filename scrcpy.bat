@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help

chcp 932
choice /m ネットワーク上のデバイスを使いますか？
if %errorlevel%==1 (
adb connect 192.168.1.51:5555
if %errorlevel%==1 set connect=ok
)
:top
echo Android 操作コマンド
echo オプションなしで接続する場合はそのままEnter
echo いずれかのオプションを付ける場合はオプションを書いてください(大文字小文字判定あり)
echo ┌───────────────────┐
echo │ 解像度変更 -m xxxx│
echo ├─────────────────┬─┘
echo │ 帯域上限 -b xK/M│
echo ├─────────────────┴───┐
echo │ FPS制限 --max-fps xx│
echo ├─────────────────────┴───────────┐
echo │ トリミング --crop 1224:1440:0:0 │
echo │ # オフセット位置(0,0)で1224x1440│
echo ├─────────────────────────────┬───┘
echo │ 回転--lock-video-orientation│
echo │  0  # 自然な向き            │
echo │  1  # 90°反時計回り        │
echo │  2  # 180°                 │
echo │  3  # 90°時計回り          │
echo ├──────────────────┬──────────┘
echo │ フルスクリーン -f│
echo ├──────────────────┤
echo │ スマホ画面オフ -S│
echo └──────────────────┘
set option=
set /P option=＞

if "%option%"=="exit" exit

if "%option%"=="" goto scrcpy
echo scrcpy %option%
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
C:\Users\kouki\OneDrive\CUIApplication\scrcpy-win64\scrcpy.exe --push-target /sdcard/Download/ %option%
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 終了
goto exit
exit

:scrcpy
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
C:\Users\kouki\OneDrive\CUIApplication\scrcpy-win64\scrcpy.exe --push-target /sdcard/Download/
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 終了

:exit
if "%connect%"=="ok" adb reconnect
choice /m もう一度やりますか？
if %errorlevel%==2 exit
goto top

:help
echo.
echo scrcpyを簡単に利用するためのバッチファイルです。
echo.
echo 使い方:
echo   %~n0
echo.
echo   引数なしで実行すると、対話形式でscrcpyのオプションを指定できます。
echo.
echo   -h, --help    このヘルプを表示します。
echo.
pause
exit /b