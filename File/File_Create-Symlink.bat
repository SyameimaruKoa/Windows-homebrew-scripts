@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help で表示）
rem 未引数、または引数1つの場合は対話的に保存先を尋ねます

chcp 932 >nul
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

setlocal enabledelayedexpansion

rem 引数の数で分岐
rem 引数なし -> 完全対話モード (ループ: 元 -> 先)
if "%~1"=="" goto :interactive_loop

rem 引数が1つだけ -> そのファイルを元として、先を聞く
if "%~2"=="" (
  set "target_arg=%~1"
  goto :single_file_mode
)

rem 引数が2つ以上 -> 先を一度聞いて、一括処理
goto :multi_args_mode

rem ========================================================
rem  完全対話モード (元指定 -> 先指定 のループ)
rem ========================================================
:interactive_loop
echo.
echo --------------------------------------------------------
echo  【元】リンク元のファイル/フォルダパスを入力（空欄で終了）
echo --------------------------------------------------------
set "target="
set /P "target=> "

rem 空入力で終了
if "!target!"=="" exit /b

rem 引用符を除去
set "target=!target:"=!"

if not exist "!target!" (
  echo 存在しません: "!target!"
  goto :interactive_loop
)

rem --- 保存先の入力 ---
:ask_dest_interactive
echo.
echo  【場所】リンクを作成するフォルダを指定せよ
echo  (例: C:\Users\kouki\.ssh)
set "dest_dir="
set /P "dest_dir=> "

if "!dest_dir!"=="" goto :ask_dest_interactive
rem 末尾の\を除去
if "!dest_dir:~-1!"=="\" set "dest_dir=!dest_dir:~0,-1!"

if not exist "!dest_dir!\" (
  echo フォルダが見つかりません: "!dest_dir!"
  goto :ask_dest_interactive
)

rem 共通処理へ飛ぶ (処理後は interactive_loop へ戻る)
call :process_link "!target!" "!dest_dir!" force_ask_name
goto :interactive_loop

rem ========================================================
rem  シングルファイルモード (引数1つ -> 先指定 -> 終了)
rem ========================================================
:single_file_mode
echo.
echo リンク元: "!target_arg!"
echo.

:ask_dest_single
echo ========================================================
echo  【場所】このリンクを作成するフォルダを指定せよ
echo ========================================================
set "dest_dir="
set /P "dest_dir=> "

if "!dest_dir!"=="" goto :ask_dest_single
if "!dest_dir:~-1!"=="\" set "dest_dir=!dest_dir:~0,-1!"

if not exist "!dest_dir!\" (
  echo フォルダが見つかりません: "!dest_dir!"
  goto :ask_dest_single
)

rem 共通処理へ (処理後は終了)
call :process_link "!target_arg!" "!dest_dir!" force_ask_name
echo.
echo 何かキーを押すと閉じます...
pause
exit /b

rem ========================================================
rem  マルチファイルモード (先指定 -> 一括処理 -> 終了)
rem ========================================================
:multi_args_mode
echo.
echo 複数ファイルが渡されました (%*)
echo.
:ask_dest_multi
echo ========================================================
echo  【場所】これらリンクをまとめて作成するフォルダを指定せよ
echo ========================================================
set "dest_dir="
set /P "dest_dir=> "

if "!dest_dir!"=="" goto :ask_dest_multi
if "!dest_dir:~-1!"=="\" set "dest_dir=!dest_dir:~0,-1!"
if not exist "!dest_dir!\" (
  echo フォルダが見つかりません: "!dest_dir!"
  goto :ask_dest_multi
)

:multi_loop
if "%~1"=="" goto :multi_end
call :process_link "%~1" "!dest_dir!" skip_ask_name
shift
goto :multi_loop

:multi_end
echo.
echo 全ての処理が完了しました。
pause
exit /b

rem ========================================================
rem  共通サブルーチン: リンク作成処理
rem  引数: %1=Target, %2=DestDir, %3=Mode(force_ask_name/skip_ask_name)
rem ========================================================
:process_link
setlocal
set "tgt=%~1"
set "dst=%~2"
set "mode=%~3"

rem ディレクトリ判定
set "is_dir=0"
if exist "!tgt!\" set "is_dir=1"

rem デフォルト名
for %%F in ("!tgt!") do set "lname=%%~nxF"

rem --- 名前変更確認 (モードによる) ---
if /i "!mode!"=="skip_ask_name" goto skip_name_input

echo.
echo  【名】作成するリンクの名前を入力せよ
echo  (空欄でEnter -> "!lname!")
set "input_name="
set /P "input_name=> "
if not "!input_name!"=="" set "lname=!input_name!"

:skip_name_input
set "full_path=!dst!\!lname!"

rem --- 存在確認と上書き (厳格なy/n) ---
if exist "!full_path!" (
  :ask_overwrite
  echo.
  echo  [警告] "!lname!" は既に存在しておる。
  echo  上書きしてよろしいか？ (y/n)
  set "ans="
  set /P "ans=> "
  
  if /i "!ans!"=="y" goto do_delete
  if /i "!ans!"=="n" (
    echo  スキップしました。
    exit /b
  )
  echo  "y" か "n" で答えるのじゃ。
  goto ask_overwrite
  
  :do_delete
  echo  既存ファイルを削除中...
  if exist "!full_path!\" (
    rmdir "!full_path!" 2>nul
    ) else (
    del /q "!full_path!"
  )
  if exist "!full_path!" (
    echo  [エラー] 削除できませんでした。権限を確認してください。
    exit /b
  )
)

rem --- 作成実行 ---
if "!is_dir!"=="1" (
  echo [フォルダリンク] !lname! -^> !tgt!
  mklink /D "!full_path!" "!tgt!" >nul
  ) else (
  echo [ファイルリンク] !lname! -^> !tgt!
  mklink "!full_path!" "!tgt!" >nul
)
if %errorlevel%==0 ( echo  成功じゃ。 ) else ( echo  失敗したようじゃ。 )

endlocal
exit /b

:show_help
echo.
echo [概要]
echo  ファイルやフォルダのシンボリックリンクを作成します。
echo  引数の数によって挙動が変わります。
echo.
echo [使い方]
echo  1. 引数なし (対話モード):
echo  %~nx0
echo  元ファイルを入力 -> 保存先を入力 -> 名前を入力 の順でループします。
echo.
echo  2. ファイルを1つドラッグ＆ドロップ:
echo  %~nx0 ^<source_path^>
echo  渡されたファイルを元として、保存先と名前を対話的に決めます。
echo.
echo  3. 複数ファイルをドラッグ＆ドロップ:
echo  %~nx0 ^<file1^> ^<file2^> ...
echo  保存先を一度だけ聞き、全てのリンクを元の名前でそこに作成します。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
