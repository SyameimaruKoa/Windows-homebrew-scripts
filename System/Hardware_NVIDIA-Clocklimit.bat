@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help

chcp 932 > nul
setlocal

rem =================================================================
rem  管理者権限で実行されているか確認し、そうでなければ自身を昇格させて再起動
rem =================================================================
:Administrator
net session >NUL 2>nul
if %errorlevel% neq 0 goto Administratorstart
goto start
exit
:Administratorstart
echo このバッチファイルは一般ユーザーには対応していないので管理者権限を要求して再起動します
where sudo >NUL 2>nul
if not errorlevel 1 (
    sudo "%~f0" %*
    exit /b
)
where gsudo >NUL 2>nul
if not errorlevel 1 (
    gsudo "%~f0" %*
    exit /b
)
@powershell start-process powershell %~0 -verb runas
if %errorlevel%==1 (
    echo 権限要求を拒否されたので再度要求します。
    goto Administrator
)
exit

:start
rem =================================================================
rem  引数がない場合は対話モードへ分岐
rem =================================================================
if "%~1"=="" goto interactive_mode

set "TARGET_VAL=%~1"
goto set_clock_direct

rem =================================================================
rem  対話モードの処理
rem =================================================================
:interactive_mode
cls
echo ============================================
echo  NVIDIA GPU クロック管理ツール (Max-Q対応)
echo ============================================
echo.
echo --- 現在のクロック状態とデフォルト最大クロック ---
echo.
nvidia-smi --query-gpu=name,clocks.current.graphics,clocks.max.graphics --format=csv
echo.
echo --------------------------------------------
echo.
set /p "TARGET_VAL=制限したい最大クロック数(MHz)か 'reset' を入力するのじゃ (終了は何も入力せずEnter): "

if not defined TARGET_VAL (
    echo 何も入力されなかったから終了するぞ。
    timeout /t 2 > nul
    goto :eof
)

rem =================================================================
rem  引数を使った直接設定モードの処理
rem =================================================================
:set_clock_direct
if /i "%TARGET_VAL%"=="reset" (
    echo クロック制限を解除するぞ...
    nvidia-smi -rgc
    echo 解除完了じゃ！
    pause
    goto :eof
)

echo.
echo GPUクロックを %TARGET_VAL% MHz に制限するぞ。よいな？
if "%~1"=="" pause > nul
echo.
nvidia-smi -lgc 210,%TARGET_VAL%
if %errorlevel% equ 0 (
    echo.
    echo 制限完了じゃ！これで少しは冷えるはずじゃのう。
) else (
    echo.
    echo 失敗したぞ。数値が間違っておらんか確認するのじゃ。
)
pause
goto :eof

:eof
endlocal
exit /b

:help
echo.
echo NVIDIA GPUの最大クロック制限を設定します。Power Limitが使えないMax-Q向けです。
echo.
echo 使い方:
echo  %~n0 [最大クロック数(MHz) ^| reset]
echo.
echo  引数なしで実行すると、対話モードでクロック制限値を設定します。
echo  引数に制限値を指定すると、直接その値に設定します。
echo  "reset" を指定すると、クロック制限を解除します。
echo.
echo  例: %~n0 1000
echo  例: %~n0 reset
echo.
echo  -h, --help  このヘルプを表示します。
echo.
pause
exit /b