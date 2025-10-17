@echo off
setlocal enabledelayedexpansion

:: コンソールの文字コードをShift-JIS（932）に設定
chcp 932 > nul

:: 引数があるかチェック
if "%~1"=="" (
    echo 対象のファイルまたはフォルダをドラッグアンドドロップしてください。
    pause
    exit /b
)

:: 圧縮モードか解除モードかを選択
echo 圧縮モードまたは解除モードを選択してください:
echo [1] 圧縮
echo [2] 圧縮解除
choice /C 12 /N /M "選択 (1-2): "

if %errorlevel%==1 goto COMPRESS
if %errorlevel%==2 goto DECOMPRESS
goto END

:COMPRESS
:: 圧縮レベルの選択
echo 圧縮レベルを選択してください:
echo [1] 最速 (XPRESS4K)
echo [2] 標準 (XPRESS8K)
echo [3] 最大 (XPRESS16K)
echo [4] LZX（最高圧縮）
choice /C 1234 /N /M "選択 (1-4): "

set "option="
if %errorlevel%==1 set "option=/EXE:XPRESS4K"
if %errorlevel%==2 set "option=/EXE:XPRESS8K"
if %errorlevel%==3 set "option=/EXE:XPRESS16K"
if %errorlevel%==4 set "option=/EXE:LZX"

:: 強制圧縮モードの確認
choice /C YN /N /M "強制圧縮モードを使用しますか？ (Y/N): "
set "force_mode=0"
if %errorlevel%==1 set "force_mode=1"

:: 圧縮処理
echo.
if %force_mode%==1 (
    echo 強制圧縮中（%option% /F）...
    for %%G in (%*) do (
        echo  - "%%~G"
        if exist "%%~G\" (
            rem フォルダの場合
            compact /C %option% /F /S:"%%~G"
        ) else (
            rem ファイルの場合
            compact /C %option% /F "%%~G"
        )
    )
) else (
    echo 圧縮中（%option%）...
    for %%G in (%*) do (
        echo  - "%%~G"
        if exist "%%~G\" (
            rem フォルダの場合
            compact /C %option% /S:"%%~G"
        ) else (
            rem ファイルの場合
            compact /C %option% "%%~G"
        )
    )
)
goto END

:DECOMPRESS
:: 圧縮解除処理
echo.
echo 圧縮解除中...
for %%G in (%*) do (
    echo  - "%%~G"
    if exist "%%~G\" (
        rem フォルダの場合
        compact /U /S:"%%~G"
    ) else (
        rem ファイルの場合
        compact /U "%%~G"
    )
)
goto END

:END
echo.
echo 全ての処理が完了しました。
endlocal
pause