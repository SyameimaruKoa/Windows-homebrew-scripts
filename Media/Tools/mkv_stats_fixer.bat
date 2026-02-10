@echo off
rem 文字コードをShift-JISに設定
chcp 932 >nul
setlocal

rem --- ヘルプと引数のチェック ---
if "%~1"=="" goto :ShowHelp
if "%~1"=="-h" goto :ShowHelp
if "%~1"=="--help" goto :ShowHelp

rem --- メイン処理ループ ---
:MainLoop
if "%~1"=="" goto :EndProcessing

rem 存在確認
if not exist "%~1" (
  echo [警告] "%~1" は見つからぬようじゃ。
  shift
  goto :MainLoop
)

rem 属性を取得してフォルダかファイルか判別
set "ATTR=%~a1"
rem 属性文字列の中に "d" (directory) が含まれているかチェック
echo "%ATTR%" | find "d" >nul
if not errorlevel 1 (
  rem フォルダの場合
  call :ProcessFolder "%~1"
  ) else (
  rem ファイルの場合
  call :ProcessFile "%~1"
)

rem 次の引数へ（複数ファイルD&D対応）
shift
goto :MainLoop

:EndProcessing
echo.
echo 全ての処理が終わったぞ。
pause
goto :eof

rem ----------------------------------------------------------
rem サブルーチン: フォルダ処理
rem ----------------------------------------------------------
:ProcessFolder
echo [フォルダ処理] "%~1" の中を調べておる...
rem /r オプションで再帰的に検索
for /r "%~1" %%F in (*.mkv *.webm) do (
  call :RunMkvPropEdit "%%F"
)
exit /b

rem ----------------------------------------------------------
rem サブルーチン: 単一ファイル処理
rem ----------------------------------------------------------
:ProcessFile
set "EXT=%~x1"
rem 拡張子判定（大文字小文字区別なし）
if /i "%EXT%"==".mkv" (
  call :RunMkvPropEdit "%~1"
  ) else if /i "%EXT%"==".webm" (
  call :RunMkvPropEdit "%~1"
  ) else (
  echo [スキップ] "%~nx1" は対象外じゃ。
)
exit /b

rem ----------------------------------------------------------
rem サブルーチン: mkvpropedit 実行
rem ----------------------------------------------------------
:RunMkvPropEdit
echo [更新中] "%~nx1"
mkvpropedit "%~1" --add-track-statistics-tags
if %errorlevel% neq 0 (
  echo [エラー] 失敗じゃ: "%~nx1"
)
exit /b

rem ----------------------------------------------------------
rem ヘルプ表示セクション
rem ----------------------------------------------------------
:ShowHelp
echo 使用法: %~nx0 [オプション] ^<ファイルまたはフォルダ^>...
echo.
echo MKV/WebMファイルの統計情報タグを一括で追加・更新するツールじゃ。
echo ファイル単体でも、フォルダごとでも、まとめて面倒見よう。
echo.
echo 使い方:
echo  1. 処理したいファイル(.mkv/.webm) または フォルダ を、
echo  このアイコンにドラッグ＆ドロップするのじゃ。
echo  （複数を一度に放り込んでも構わんぞ）
echo.
echo オプション:
echo  -h, --help  このヘルプを表示して待機する
echo.
pause
goto :eof
