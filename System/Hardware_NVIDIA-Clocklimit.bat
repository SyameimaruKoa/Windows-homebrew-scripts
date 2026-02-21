@echo off
rem 下にヘルプがあります
if "%1"=="-h" goto help
if "%1"=="--help" goto help

chcp 932 > nul
setlocal enabledelayedexpansion

rem =================================================================
rem  管理者権限で実行されているか確認し、そうでなければ自身を昇格させて再起動
rem  プライマリ: gsudo  セカンダリ: PowerShell -verb runas
rem =================================================================
:Administrator
net session >NUL 2>nul
if %errorlevel% neq 0 goto Administratorstart
goto start

:Administratorstart
echo このバッチファイルは一般ユーザーには対応していないので管理者権限を要求して再起動します
where gsudo >nul 2>&1
if %errorlevel%==0 (
  echo gsudo を使用して昇格します...
  gsudo "%~f0" %*
  exit /b
)
echo gsudo が見つからないため PowerShell で昇格します...
@powershell start-process cmd -ArgumentList '/c','"%~f0" %*' -verb runas
exit /b

:start
rem =================================================================
rem  引数がある場合は直接設定モード、ない場合は対話モードへ分岐
rem =================================================================
if "%1"=="" (
  goto :interactive_mode
  ) else (
  goto :set_clock_direct
)

rem =================================================================
rem  対話モードの処理
rem =================================================================
:interactive_mode
cls
echo ============================================
echo  NVIDIA GPU クロックリミット管理ツール
echo ============================================
echo.
echo --- 現在の電力状態 ---
echo.
nvidia-smi -q -d power
echo.
echo --------------------------------------------
echo.
set /p "INPUT=新しいクロックリミット(低,高 MHz)を入力 (例: 300,885 / 終了はEnter): "

if not defined INPUT (
  echo 何も入力されなかったから終了するぞ。
  timeout /t 2 > nul
  goto :eof
)

rem カンマで分割
set "LOW="
set "HIGH="
for /f "tokens=1,2 delims=," %%a in ("!INPUT!") do (
  set "LOW=%%a"
  set "HIGH=%%b"
)

if not defined HIGH (
  echo.
  echo 入力形式が不正じゃ。"低,高" の形式で指定するのじゃ。
  pause
  goto :eof
)

rem サポート範囲チェック
call :check_supported_range

echo.
echo 低リミットを【!LOW!MHz】、高リミットを【!HIGH!MHz】に変更する。よいな？
pause > nul
echo.
nvidia-smi -lgc !LOW!,!HIGH!
echo.
echo 変更しておいたぞ。感謝するがよい。
pause
goto :eof

rem =================================================================
rem  引数を使った直接設定モードの処理 (低,高 形式)
rem =================================================================
:set_clock_direct
set "LOW="
set "HIGH="
for /f "tokens=1,2 delims=," %%a in ("%~1") do (
  set "LOW=%%a"
  set "HIGH=%%b"
)

if not defined HIGH (
  echo 引数「%~1」の形式が不正じゃ。"低,高" の形式で指定するのじゃ。
  echo 例: %~n0 300,885
  goto :eof
)

rem サポート範囲チェック
call :check_supported_range

echo 低リミット !LOW!MHz, 高リミット !HIGH!MHz に設定するのじゃ...
nvidia-smi -lgc !LOW!,!HIGH!
echo 設定が完了したはずじゃ。
goto :eof

rem =================================================================
rem  サポートされているGraphicsクロックの最小/最大を取得し、
rem  LOW / HIGH が範囲外なら警告を表示するサブルーチン
rem =================================================================
:check_supported_range
set "MINCLK=999999"
set "MAXCLK=0"
for /f "tokens=2 delims=:" %%a in ('nvidia-smi -q -d SUPPORTED_CLOCKS 2^>nul ^| findstr /C:"Graphics"') do (
  for /f "tokens=1" %%b in ("%%a") do (
    set /a "_v=%%b" 2>nul
    if !_v! gtr 0 (
      if !_v! lss !MINCLK! set "MINCLK=!_v!"
      if !_v! gtr !MAXCLK! set "MAXCLK=!_v!"
    )
  )
)
rem 取得できなかった場合はチェックをスキップ
if !MINCLK!==999999 (
  echo サポートクロック情報を取得できなかったため、範囲チェックをスキップするぞ。
  goto :eof
)

echo サポート範囲: !MINCLK!MHz ～ !MAXCLK!MHz
if !LOW! lss !MINCLK! (
  echo [警告] 低リミット !LOW!MHz はサポート範囲より低いです。下限 !MINCLK!MHz が適用されます。
)
if !HIGH! gtr !MAXCLK! (
  echo [警告] 高リミット !HIGH!MHz はサポート範囲より高いです。上限 !MAXCLK!MHz が適用されます。
)
if !LOW! gtr !MAXCLK! (
  echo [警告] 低リミット !LOW!MHz はサポート範囲の上限 !MAXCLK!MHz を超えています。
)
if !HIGH! lss !MINCLK! (
  echo [警告] 高リミット !HIGH!MHz はサポート範囲の下限 !MINCLK!MHz を下回っています。
)
goto :eof

:eof
endlocal
exit /b

:help
echo.
echo NVIDIA GPUのグラフィックスクロックリミット(低/高)を設定します。
echo.
echo 使い方:
echo  %~n0 [低,高]
echo.
echo  引数なしで実行すると、対話モードでリミット値を設定します。
echo  引数にリミットを指定すると、直接その値に設定します。
echo.
echo  例: %~n0 300,885  (低300MHz, 高885MHz)
echo  %~n0 128,2100  (低128MHz, 高2100MHz)
echo.
echo  -h, --help  このヘルプを表示します。
echo.
pause
exit /b
