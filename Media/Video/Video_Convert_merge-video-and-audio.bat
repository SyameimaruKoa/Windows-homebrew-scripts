@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
setlocal enabledelayedexpansion
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932 >nul

rem 引数をすべて配列に格納
set /a arg_count=0
set /a pair_count=0
:count_args
if "%~1"=="" goto :count_done
set /a arg_count+=1
set "arg[!arg_count!]=%~1"
set "arg_name[!arg_count!]=%~nx1"
shift
goto :count_args

:count_done
rem ペア数を計算（偶数個の引数が必要）
set /a pair_count=arg_count/2
if !arg_count! LSS 2 (
    echo エラー: 最低でも動画ファイルと音声ファイルの2つが必要です。
    pause
    exit /b 1
)
set /a remainder=arg_count%%2
if !remainder! NEQ 0 (
    echo エラー: 引数は偶数個（動画+音声のペア）で指定してください。
    echo 現在の引数数: !arg_count!
    pause
    exit /b 1
)

rem ファイル一覧を表示
echo.
echo ============ 入力ファイル一覧 ============
for /L %%i in (1,2,!arg_count!) do (
    set /a j=%%i+1
    set /a pair_num=(%%i+1)/2
    echo [ペア!pair_num!] 動画: !arg_name[%%i]!
    echo [ペア!pair_num!] 音声: !arg_name[!j!]!
    echo.
)
echo ==========================================
echo.

rem 拡張子選択
choice /m "拡張子をMP4にする場合はNを、MKVにする場合はYを押してください"
if !errorlevel!==1 set extension=mkv
if !errorlevel!==2 set extension=mp4

rem 単純結合の場合（1ペアのみ）
if !pair_count! EQU 1 goto :simple_combining

rem マルチトラック化：ストリーム名入力
echo.
echo ========== ストリーム名の設定 ==========
for /L %%i in (1,1,!pair_count!) do (
    echo [ペア%%i] ストリーム名を入力してください:
    set /P "stream_name[%%i]="
    if "!stream_name[%%i]!"=="" set "stream_name[%%i]=Track %%i"
)
echo ==========================================
echo.

rem プロパティコピー元の選択
echo どのファイルからプロパティをコピーしますか？
echo 0: コピーしない
for /L %%i in (1,1,!arg_count!) do (
    echo %%i: !arg_name[%%i]!
)
set /P property_choice=番号を入力してください (0-!arg_count!): 
if "!property_choice!"=="" set property_choice=0
if !property_choice! EQU 0 (
    set properties=no
) else (
    set "properties=!arg[%property_choice%]!"
)

rem ffmpegコマンドを動的に構築
set "ffmpeg_cmd=ffmpeg -hide_banner"
set "map_cmd="
set "metadata_cmd="

rem 入力ファイル指定
for /L %%i in (1,1,!arg_count!) do (
    set "ffmpeg_cmd=!ffmpeg_cmd! -i "!arg[%%i]!""
)

rem マップとメタデータを構築
set /a v_index=0
set /a a_index=0
for /L %%i in (1,2,!arg_count!) do (
    set /a input_v=%%i-1
    set /a input_a=%%i
    set /a pair_num=(%%i+1)/2
    
    set "map_cmd=!map_cmd! -map !input_v!:v:0"
    set "map_cmd=!map_cmd! -map !input_a!:a:0"
    
    set "metadata_cmd=!metadata_cmd! -metadata:s:v:!v_index! title="!stream_name[%pair_num%]!""
    set "metadata_cmd=!metadata_cmd! -metadata:s:a:!a_index! title="!stream_name[%pair_num%]!""
    
    set /a v_index+=1
    set /a a_index+=1
)

rem 出力ファイル名を取得（最初の入力ファイルをベースに）
for %%A in ("!arg[1]!") do (
    set "output_dir=%%~dpA"
    set "output_name=%%~nA"
)
set "output_file=!output_dir!!output_name! Multitrack.!extension!"

rem ffmpegを実行
echo.
echo !pair_count!組の動画をマルチトラック化します...
echo.
!ffmpeg_cmd! -c copy !map_cmd! !metadata_cmd! "!output_file!"

rem プロパティのコピー
if not "!properties!"=="no" (
    echo.
    echo プロパティをコピーしています...
    exiftool -api largefilesupport=1 -tagsfromfile "!properties!" -all:all -overwrite_original "!output_file!"
)

goto :exit_success

:simple_combining
rem 単純結合処理（1ペアのみ）
echo 動画と音声を結合します。
echo ──────────────────────────────
echo 動画: !arg_name[1]!
echo 音声: !arg_name[2]!
echo.
choice /c 012 /n /m "どのファイルからプロパティをコピーしますか？(0:しない 1:動画 2:音声)"
if !errorlevel!==1 set properties=no
if !errorlevel!==2 set "properties=!arg[1]!"
if !errorlevel!==3 set "properties=!arg[2]!"

for %%A in ("!arg[1]!") do (
    set "output_dir=%%~dpA"
    set "output_name=%%~nA"
)
set "output_file=!output_dir!!output_name! (combining).!extension!"

ffmpeg -hide_banner -i "!arg[1]!" -i "!arg[2]!" -c copy -map 0:v:0 -map 1:a:0 "!output_file!"

if not "!properties!"=="no" (
    echo.
    echo プロパティをコピーしています...
    exiftool -api largefilesupport=1 -tagsfromfile "!properties!" -all:all -overwrite_original "!output_file!"
)

:exit_success
echo.
if !errorlevel!==0 (
    echo ? 成功しました。
    echo 出力: !output_file!
) else (
    echo ? 失敗しました。
)
echo.
pause
exit /b !errorlevel!

:show_help
echo.
echo [概要]
echo   動画と音声を結合、または複数の動画^+音声をマルチトラック化し、各ストリームにタイトルを設定します。
echo.
echo [使い方]
echo   - 単純結合: %~nx0 ^<video1^> ^<audio1^>
echo   - 2組:      %~nx0 ^<video1^> ^<audio1^> ^<video2^> ^<audio2^>
echo   - 3組:      %~nx0 ^<v1^> ^<a1^> ^<v2^> ^<a2^> ^<v3^> ^<a3^>
echo   - 4組:      %~nx0 ^<v1^> ^<a1^> ^<v2^> ^<a2^> ^<v3^> ^<a3^> ^<v4^> ^<a4^>
echo   対話で拡張子(MKV/MP4)とストリーム名（タイトル）を指定できます。
echo.
echo [メモ]
echo   exiftool があれば、元ファイルからプロパティをコピーできます。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b