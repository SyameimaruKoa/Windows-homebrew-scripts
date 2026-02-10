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
@powershell start-process powershell %~0 -verb runas
if %errorlevel%==1 (
echo 権限要求を拒否されたので再度要求します。
goto Administrator
)
exit

:start
rem =================================================================
rem  引数がない場合はヘルプを表示
rem =================================================================
if "%1"=="" goto help

rem =================================================================
rem  引数がある場合は直接設定モード、ない場合は対話モードへ分岐
rem =================================================================
if not "%1"=="" (
    goto :set_power_direct
) else (
    goto :interactive_mode
)


rem =================================================================
rem  対話モードの処理
rem =================================================================
:interactive_mode
cls
echo ============================================
echo      NVIDIA GPU 電力管理ツール
echo ============================================
echo.
echo --- 現在の電力状態 ---
echo.
nvidia-smi -q -d power
echo.
echo --------------------------------------------
echo.
set /p "POWER_LIMIT=新しい電力制限値(W)を入力するのじゃ (終了は何も入力せずEnter): "

if not defined POWER_LIMIT (
    echo 何も入力されなかったから終了するぞ。
    timeout /t 2 > nul
    goto :eof
)

echo.
echo 電力制限を【%POWER_LIMIT%W】に変更する。よいな？
pause > nul
echo.
nvidia-smi -pl %POWER_LIMIT%
echo.
echo 変更しておいたぞ。感謝するがよい。
pause
goto :eof


rem =================================================================
rem  引数を使った直接設定モードの処理
rem =================================================================
:set_power_direct
echo 引数「%1」を使って電力制限を %1W に変更するのじゃ...
nvidia-smi -pl %1
echo 変更が完了したはずじゃ。
goto :eof


:eof
endlocal
exit /b

:help
echo.
echo NVIDIA GPUの電力制限を設定します。
echo.
echo 使い方:
echo   %~n0 [電力制限値(W)]
echo.
echo   引数なしで実行すると、対話モードで電力制限値を設定します。
echo   引数に電力制限値を指定すると、直接その値に設定します。
echo.
echo   例: %~n0 150
echo.
echo   -h, --help    このヘルプを表示します。
echo.
pause
exit /b