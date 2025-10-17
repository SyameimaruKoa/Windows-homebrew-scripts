@echo off
chcp 932 >nul

setlocal enabledelayedexpansion

set "TARGET=%~1"
if not defined TARGET (
    echo フォルダをD&Dしてほしいのじゃ。
    pause
    exit /b
)

cd /d "%TARGET%"

for %%F in (*.*) do (
    set "FILE=%%F"
    for /f "tokens=1,2 delims=/" %%a in ("%%~tF") do (
        set "YEAR=%%a"
        set "MONTH=%%b"
        set "DESTFOLDER=!YEAR!-!MONTH!"

        if not exist "!DESTFOLDER!" (
            mkdir "!DESTFOLDER!"
        )

        move "%%F" "!DESTFOLDER!\"
    )
)

echo 完了じゃ。
pause
