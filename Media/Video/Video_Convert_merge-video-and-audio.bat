@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
setlocal enabledelayedexpansion
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932 >nul

rem 指定されたファイルを順番に登録する
set /a arg_count=0
:count_args
if "%~1"=="" goto :count_done
if not exist "%~1" (
    echo エラー: ファイルが見つかりません: "%~1"
    exit /b 1
)
set /a arg_count+=1
set "arg[!arg_count!]=%~1"
set "arg_name[!arg_count!]=%~nx1"
shift
goto :count_args

:count_done
set "probe_file=%TEMP%\merge_streams_%RANDOM%_%RANDOM%.csv"
set /a stream_count=0
set "probe_failed=0"
echo.
echo ============ 利用可能なストリーム ============
for /L %%I in (1,1,!arg_count!) do call :probe_file %%I
if "!probe_failed!"=="1" exit /b 1
if !stream_count! EQU 0 (
    echo エラー: 動画・音声ストリームが見つかりません。
    exit /b 1
)
echo ============================================
echo.
echo 使用するストリームを出力順に選んでください。
echo 同じファイルから複数選択できます。何も入力せずEnterで確定します。
set /a selected_count=0
set /a video_count=0
set /a audio_count=0
set "map_cmd="
set "metadata_cmd="

:select_stream
set "selection="
set /p "selection=ストリーム番号 (1-!stream_count!, Enterで確定): "
if not defined selection (
    if !selected_count! EQU 0 (
        echo エラー: 最低1つ選択してください。
        exit /b 1
    )
    goto :selection_done
)
set "selected_id="
for /L %%I in (1,1,!stream_count!) do if "!selection!"=="%%I" set "selected_id=%%I"
if not defined selected_id goto :invalid_selection
set /a selected_count+=1
set "map_cmd=!map_cmd! -map !stream_map[%selected_id%]!"
if "!stream_type[%selected_id%]!"=="v" (
    set "metadata_spec=v:!video_count!"
    set /a video_count+=1
) else (
    set "metadata_spec=a:!audio_count!"
    set /a audio_count+=1
)
echo 選択: !stream_desc[%selected_id%]!
set "stream_title="
set /p "stream_title=タイトル (空欄なら設定しない): "
if defined stream_title set "metadata_cmd=!metadata_cmd! -metadata:s:!metadata_spec! "title=!stream_title!""
goto :select_stream

:invalid_selection
echo 1から!stream_count!までの番号を入力してください。
goto :select_stream

:selection_done
echo.
choice /c 12 /m "出力形式を選択 [1]MKV [2]MP4"
if errorlevel 2 (set "extension=mp4") else (set "extension=mkv")
echo.
echo プロパティをコピーする元ファイルを選択してください。
echo 0: コピーしない
for /L %%I in (1,1,!arg_count!) do echo %%I: !arg_name[%%I]!
:select_properties
set "property_choice="
set /p "property_choice=番号 (0-!arg_count!, Enterで0): "
if not defined property_choice set "property_choice=0"
set "property_id="
for /L %%I in (0,1,!arg_count!) do if "!property_choice!"=="%%I" set "property_id=%%I"
if not defined property_id goto :invalid_property_choice
if !property_id! GTR 0 set "properties=!arg[%property_id%]!"
goto :properties_done
:invalid_property_choice
echo 0から!arg_count!までの番号を入力してください。
goto :select_properties

:properties_done
set "ffmpeg_inputs="
for /L %%I in (1,1,!arg_count!) do set "ffmpeg_inputs=!ffmpeg_inputs! -i "!arg[%%I]!""
for %%A in ("!arg[1]!") do (
    set "output_dir=%%~dpA"
    set "output_name=%%~nA"
)
set "output_file=!output_dir!!output_name! (merged).!extension!"
if exist "!output_file!" (
    echo エラー: 出力先に同名のファイルがあります: "!output_file!"
    exit /b 1
)
echo.
echo 動画 !video_count! 本、音声 !audio_count! 本を結合します...
ffmpeg -hide_banner !ffmpeg_inputs! -map_metadata -1 -c copy !map_cmd! !metadata_cmd! "!output_file!"
if errorlevel 1 goto :conversion_failed
if not exist "!output_file!" goto :conversion_failed
for %%A in ("!output_file!") do if %%~zA EQU 0 goto :conversion_failed
if defined properties (
    echo プロパティをコピーしています...
    exiftool -api largefilesupport=1 -tagsfromfile "!properties!" -all:all -overwrite_original "!output_file!"
    if errorlevel 1 (
        echo エラー: プロパティのコピーに失敗しました。出力ファイルは保持します。
        exit /b 1
    )
)
echo.
echo 成功しました。出力: "!output_file!"
pause
exit /b 0

:conversion_failed
echo.
echo エラー: 結合に失敗しました。
pause
exit /b 1

:probe_file
set /a input_index=%~1-1
echo [入力%~1] !arg_name[%~1]!
ffprobe -v error -show_entries stream=index,codec_name,codec_type -of csv=p=0 "!arg[%~1]!" <nul >"!probe_file!"
if errorlevel 1 (
    echo エラー: ストリームを調べられません: "!arg[%~1]!"
    set "probe_failed=1"
    del /q "!probe_file!" >nul 2>nul
    goto :eof
)
for /f "usebackq tokens=1-3 delims=," %%A in ("!probe_file!") do (
    if /i "%%C"=="video" call :add_stream %%A v %%B
    if /i "%%C"=="audio" call :add_stream %%A a %%B
)
del /q "!probe_file!" >nul 2>nul
goto :eof

:add_stream
set /a stream_count+=1
set "stream_map[!stream_count!]=!input_index!:%~1"
set "stream_type[!stream_count!]=%~2"
set /a display_input=input_index+1
set "stream_desc[!stream_count!]=入力!display_input! ストリーム%~1 %~2 %~3"
echo   [!stream_count!] ストリーム%~1 %~2 (%~3)
goto :eof

:show_help
echo.
echo [概要]
echo   複数ファイル内の動画・音声ストリームを選び、1つのMKVまたはMP4にコピー結合します。
echo   元の動画に入っている音声を選ばず、別の音声を選べば置き換えられます。
echo.
echo [使い方]
echo   %~nx0 ^<file1^> [file2] [file3] ...
echo   動画と音声をペアで指定する必要はありません。
echo   一覧に表示された番号で、使用するストリームと出力順を指定します。
echo   例: 動画1本と音声3本、動画3本と音声1本、単一コンテナ内の複数ストリーム。
echo   必要に応じて各ストリームのタイトルとプロパティのコピー元を選べます。
echo.
echo [前提]
echo   ffprobe と ffmpeg が PATH に必要です。プロパティをコピーする場合は exiftool も必要です。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b