@echo off
rem 詳しいヘルプは末尾の :help に記載しています。
chcp 932 >nul
setlocal EnableExtensions EnableDelayedExpansion

if /I "%~1"=="-h" goto help
if /I "%~1"=="--help" goto help
if not "%~1"=="" goto invalid_arguments

rem PATH と標準インストール先から Tailscale CLI を探します。
set "TAILSCALE_EXE="
for %%F in (tailscale.exe) do if not "%%~$PATH:F"=="" set "TAILSCALE_EXE=%%~$PATH:F"
if not defined TAILSCALE_EXE if exist "%ProgramFiles%\Tailscale\tailscale.exe" set "TAILSCALE_EXE=%ProgramFiles%\Tailscale\tailscale.exe"
if not defined TAILSCALE_EXE if exist "%LocalAppData%\Tailscale\tailscale.exe" set "TAILSCALE_EXE=%LocalAppData%\Tailscale\tailscale.exe"
if not defined TAILSCALE_EXE (
    echo [エラー] tailscale.exe が見つかりません。Tailscale をインストールしてください。
    pause
    exit /b 1
)
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [エラー] Windows PowerShell が見つかりません。
    pause
    exit /b 1
)

:menu
cls
echo ==============================================
echo     Tailscale Exit Node 切り替え
echo ==============================================
echo.
echo 利用できる Exit Node を取得しています...
set "NODE_COUNT=0"
set "TS_EXIT_JSON=%TEMP%\tailscale-exit-node-!RANDOM!-!RANDOM!.json"
"%TAILSCALE_EXE%" status --json >"!TS_EXIT_JSON!" 2>nul
if errorlevel 1 (
    del /q "!TS_EXIT_JSON!" >nul 2>&1
    echo [エラー] Tailscale の状態を取得できませんでした。
    echo Tailscale の起動・ログイン状態を確認してください。
    echo.
    pause
    goto menu
)

rem JSON は Windows 標準の PowerShell で解析します。候補と現在の選択状態を表示します。
rem CLI から受け取る IP アドレスは PowerShell 側で形式を制限します。
for /f "usebackq tokens=1-4 delims=|" %%A in (`powershell.exe -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $s=ConvertFrom-Json -InputObject (Get-Content -LiteralPath $env:TS_EXIT_JSON -Raw -Encoding UTF8); foreach($property in $s.Peer.PSObject.Properties){$p=$property.Value; if($p.ExitNodeOption -or $p.ExitNode){$ip=@($p.TailscaleIPs)[0]; if($ip -match '^[0-9a-fA-F:.]+$'){Write-Output ($ip+'|'+$p.HostName+'|'+$p.Online+'|'+$p.ExitNode)}}}" 2^>nul`) do (
    set /a NODE_COUNT+=1 >nul
    set "NODE_!NODE_COUNT!=%%A"
    set "NODE_FLAGS="
    if /I "%%D"=="True" set "NODE_FLAGS=[使用中]"
    if /I "%%C"=="False" set "NODE_FLAGS=!NODE_FLAGS! [オフライン]"
    echo   !NODE_COUNT!^) %%B ^(%%A^) !NODE_FLAGS!
)
del /q "!TS_EXIT_JSON!" >nul 2>&1
if !NODE_COUNT! EQU 0 (
    echo.
    echo   ^(利用可能な Exit Node が見つかりません^)
    echo   ^(Tailscale の接続・Exit Node の承認状態を確認してください^)
)

echo.
echo   0^) Exit Node を無効化
echo   R^) 一覧を再取得
echo   H^) ヘルプ
echo   Q^) 終了
echo.
set "SELECT="
set /p "SELECT=番号または操作を選択: "
if /I "!SELECT!"=="Q" goto finish
if /I "!SELECT!"=="H" goto help
if /I "!SELECT!"=="R" goto menu
if "!SELECT!"=="0" goto disable

rem 存在する番号と完全一致した場合だけ、その候補の IP を使用します。
set "SELECTED_IP="
for /l %%N in (1,1,!NODE_COUNT!) do (
    if "!SELECT!"=="%%N" set "SELECTED_IP=!NODE_%%N!"
)
if not defined SELECTED_IP (
    echo [エラー] 選択が正しくありません。
    pause
    goto menu
)

echo.
echo Exit Node !SELECTED_IP! を有効にします...
"%TAILSCALE_EXE%" set --exit-node=!SELECTED_IP!
if errorlevel 1 (
    echo [エラー] Exit Node の切り替えに失敗しました。
) else (
    echo [完了] Exit Node を !SELECTED_IP! に設定しました。
)
echo.
pause
goto menu

:disable
echo.
echo Exit Node を無効にします...
"%TAILSCALE_EXE%" set --exit-node=
if errorlevel 1 (
    echo [エラー] Exit Node を無効化できませんでした。
) else (
    echo [完了] Exit Node を無効化しました。
)
echo.
pause
goto menu

:invalid_arguments
echo [エラー] 対応していない引数です: %~1
echo.
goto help

:finish
endlocal
exit /b 0

:help
echo.
echo Tailscale の Exit Node を一覧から選択して有効化・無効化するバッチファイルです。
echo.
echo 使い方:
echo   %~nx0             対話型メニューを表示
echo   %~nx0 -h          このヘルプを表示
echo   %~nx0 --help      このヘルプを表示
echo.
echo メニュー:
echo   1,2,...   一覧の番号を指定して Exit Node を有効化・切り替え
echo   0         Exit Node を無効化
echo   R         候補一覧を再取得
echo   H         ヘルプを表示
echo   Q         終了
echo.
echo 仕様:
echo   - Tailscale が公開する Exit Node 候補と現在の使用状態を表示します。
echo   - オフラインのノードも一覧に表示し、オフラインと明記します。
echo   - tailscale set を使用し、他の Tailscale 設定は変更しません。
echo   - Windows 標準の PowerShell と Tailscale CLI が必要です。
echo   - 通常、管理者権限は不要です。Tailscale 側のポリシーには従います。
echo   - Tailscale はログイン済みで、Exit Node が利用許可されている必要があります。
echo.
if "%~1"=="" (
    pause
    goto menu
)
endlocal
exit /b 0
