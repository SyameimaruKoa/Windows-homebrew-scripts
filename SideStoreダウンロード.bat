@chcp 932
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help
if "%1"=="" goto help

@cd /D C:\RAMDASK\
@if %errorlevel%==1 (
echo "RAMディスクが見つかりませんでした。Downloadフォルダに移動します"
cd /D "%USERPROFILE%\Downloads"
)
aria2c https://github.com/SideStore/SideStore/releases/download/nightly/SideStore.ipa
@exit

:help
echo.
echo SideStoreの最新版(nightly)をダウンロードします。
echo.
echo 使い方:
echo   %~n0 [引数]
echo.
echo   何かしらの引数を指定して実行してください。
echo   例: %~n0 start
echo.
echo   -h, --help    このヘルプを表示します。
echo.
pause
exit /b