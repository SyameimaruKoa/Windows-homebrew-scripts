@echo off
setlocal

:: 引数がない場合はヘルプを表示して終了（ユーザー入力待ち）
if "%~1"=="" (
  call :show_help
  pause
  exit /b
)

:: ヘルプ引数のチェック
if "%~1"=="-h" (
  call :show_help
  exit /b
)
if "%~1"=="--help" (
  call :show_help
  exit /b
)

:: ドラッグ＆ドロップされたファイルを順次処理
:loop
if "%~1"=="" goto :eof

echo ---------------------------------------------------
echo Processing: "%~1"

:: UPX実行
:: --best: 最高圧縮
:: -k: バックアップを作成
upx.exe --best -k "%~1"

if %errorlevel% neq 0 (
  echo [ERROR] 圧縮に失敗したようじゃ: "%~1"
  ) else (
  echo [SUCCESS] 圧縮完了じゃ！
)

shift
goto :loop

exit /b

:: --- ヘルプ関数 ---
:show_help
echo ========================================================
echo  UPX Easy Compressor
echo ========================================================
echo Usage:
echo  Drag and drop .exe files onto this batch file.
echo  Or run from command line: %~nx0 [file1] [file2] ...
echo.
echo Options:
echo  -h, --help  Show this help message.
echo.
echo Features:
echo  - Compresses using '--best' compression.
echo  - Creates a backup ('-k') of the original file.
echo ========================================================
exit /b
