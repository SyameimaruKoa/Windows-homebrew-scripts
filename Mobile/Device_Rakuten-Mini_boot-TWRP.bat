@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help

cd "%~dp0"
chcp 932
choice /c 123 /m "1：TWRP 2：Reboot→Bootloader→TWRP 3：BootloaderOnly"
if %errorlevel%==2 goto bootloader
if %errorlevel%==3 goto bootloaderonly
goto twrpboot
exit

:bootloader
echo ブートローダーに再起動するよ
adb reboot bootloader

:twrpboot
echo 圧縮されたTWRPを展開するから待つのじゃ...
7z x "%~dp0TWRP-3.4.0-1_C330.img.zst" -o"%TEMP%" -y >nul
if errorlevel 1 (
    echo エラー：展開に失敗したのじゃ。7zコマンドが使える状態か確認するのじゃ。
    pause
    exit /b
)
echo TWRPを起動するよ
fastboot boot "%TEMP%\TWRP-3.4.0-1_C330.img"
del "%TEMP%\TWRP-3.4.0-1_C330.img"
exit

:bootloaderonly
echo ブートローダーに再起動するよ
adb reboot bootloader
exit

:help
echo.
echo Rakuten Mini をTWRPで起動するためのバッチファイルです。
echo.
echo 使い方:
echo  %~n0
echo.
echo  引数なしで実行すると、操作を選択するプロンプトが表示されます。
echo.
echo  1: TWRPを起動します。
echo  2: Bootloaderに再起動してからTWRPを起動します。
echo  3: Bootloaderに再起動します。
echo.
echo  -h, --help  このヘルプを表示します。
echo.
pause
exit /b
