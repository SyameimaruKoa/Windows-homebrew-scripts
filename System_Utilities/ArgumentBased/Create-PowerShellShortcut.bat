@echo off
setlocal enabledelayedexpansion
rem Shift-JIS (ANSI) で保存してください。

rem =================================================================
rem このバッチファイルの下部にヘルプ（使い方）が記載されています。
rem =================================================================

rem 引数が指定されていないか、ヘルプオプションが指定された場合はヘルプを表示
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

rem --- メイン処理 ---
echo PowerShellショートカットを一括作成します...
echo.

rem %* を使って、ドラッグアンドドロップされた全てのファイルをループ処理
for %%F in (%*) do (
    echo [処理中] "%%~nxF"

    rem ショートカットファイルのパスを生成 (例: C:\Script\MyScript.ps1 -> C:\Script\MyScript.ps1.lnk)
    set "shortcutPath=%%~F.lnk"

    rem 一時的に使用するVBScriptのパスを生成
    set "vbsPath=%TEMP%\create_shortcut_!RANDOM!.vbs"

    rem ショートカットを作成するためのVBScriptを生成
    (
      echo Set oWS = WScript.CreateObject("WScript.Shell"^)
      echo sLinkFile = "!shortcutPath!"
      echo Set oLink = oWS.CreateShortcut(sLinkFile^)
      echo oLink.TargetPath = "powershell.exe"
      echo oLink.Arguments = "-ExecutionPolicy Bypass -NoProfile -File ""%%~F"""
      echo oLink.IconLocation = "powershell.exe, 0"
      echo oLink.Save
    ) > "!vbsPath!"

    rem VBScriptを実行してショートカットを作成
    cscript //nologo "!vbsPath!"

    rem 一時ファイルを削除
    del "!vbsPath!" > nul 2>&1

    echo   => [作成完了] "!shortcutPath!"
    echo.
)

echo ----------------------------------------
echo   全ての処理が完了しました！
echo ----------------------------------------
echo.
echo 何かキーを押すと終了します...
pause > nul
goto :eof


:show_help
rem --- ヘルプ表示 ---
echo.
echo =================================================================
echo   PowerShellスクリプトをD&Dで実行するショートカットを作成する
echo =================================================================
echo.
echo [使い方]
echo   このバッチファイルに、ショートカットを作成したい
echo   PowerShellスクリプトファイル (*.ps1^) を
echo   複数まとめてドラッグアンドドロップしてください。
echo.
echo [処理内容]
echo   ドラッグされた各スクリプトと同じフォルダに、
echo   「元のファイル名.ps1.lnk」という名前で
echo   そのスクリプトを実行するためのショートカットが作成されます。
echo.
echo   ショートカットの「作業フォルダ」は意図的に空白に設定されます。
echo.
echo =================================================================
echo.
echo 何かキーを押して終了してください...
pause
exit /b