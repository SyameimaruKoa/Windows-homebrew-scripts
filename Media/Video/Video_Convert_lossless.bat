@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
rem 遅延環境変数を有効にする。ループ内で変数を正しく扱うために必要じゃ。
setlocal enabledelayedexpansion

rem --- 初期設定 ---
rem 文字コードをShift-JISに設定する。日本語のファイル名を正しく扱うためじゃ。
chcp 932

rem ★★★ エラー発生を記録する旗印 ★★★
set "_error_occurred=0"

rem =================================================================
rem ★★★ ここからが変更箇所 (連続処理・モード判定) ★★★
rem =================================================================
set "target_files="
set "_run_as_session_mpd_mode=no"
set "_folder_drop_mode=no"

rem --- 判定1: 引数に "session.mpd" を含むフォルダがあるか (連続処理対応) ---
for %%A in (%*) do (
    rem %%Aがフォルダかどうかを判定
    if exist "%%~A\" (
        if exist "%%~A\session.mpd" (
            echo "%%~nxA" 内の "session.mpd" を処理対象に追加するぞ。
            rem target_files変数に処理対象のフルパスを追記していく
            set "target_files=!target_files! "%%~A\session.mpd""
            set "_run_as_session_mpd_mode=yes"
            set "_folder_drop_mode=yes"
        )
    )
)

rem --- 判定2: "session.mpd" ファイルが直接指定されたか ---
rem フォルダD&Dモードでなかった場合のみ、ファイルでの判定を行う
if "%_folder_drop_mode%"=="no" (
    for %%A in (%*) do (
        if /i "%%~nxA"=="session.mpd" (
            echo "session.mpd" ファイルを検知したぞ。
            rem 処理対象は全ての引数とする
            set "target_files=%*"
            set "_run_as_session_mpd_mode=yes"
            goto :setup_session_mpd_mode
        )
    )
)

rem --- session.mpd モードのセットアップ ---
:setup_session_mpd_mode
if "%_run_as_session_mpd_mode%"=="yes" (
    echo 固定設定で処理を開始するのじゃ。
    set "_session_mpd_mode=yes"
    set "_delete_original=no"
    set "_output_ext=mp4"
    set "_keep_all_streams=yes"
    set "_audio_mode=copy"
    goto :file_loop_start
)

rem --- 通常モードの処理 ---
set "target_files=%*"
call :configure_options %*
if "%_exit_script%"=="true" exit /b

rem =================================================================
rem ★★★ 変更箇所はここまで ★★★
rem =================================================================


rem --- ファイル処理ループ ---
:file_loop_start
echo.
echo --- 処理開始 ---
set /a "file_count=0"
set /a "total_files=0"
rem まずはファイルの総数を数える
for %%A in (%target_files%) do set /a total_files+=1

rem forループで各ファイルを処理する
for %%F in (%target_files%) do (
    set /a "file_count+=1"
    call :process_file %%F
)


rem --- 終了処理 ---
echo.
echo --- 全ての処理が完了したぞ ---
rem ★★★ エラーがあった場合のみ一時停止する ★★★
if "%_error_occurred%"=="1" (
    echo 何か問題が発生したようじゃ。画面を確認せよ。
    pause
)
exit /b


rem =================================================================
:configure_options
rem --- 動作設定のサブルーチン ---

echo.
choice /m "処理後に元のファイルを削除するか？"
if %errorlevel%==1 (
    set "_delete_original=yes"
    echo 元のファイルは削除する設定にしたぞ。
) else (
    set "_delete_original=no"
    echo 元のファイルは保持する設定にしたぞ。
)

echo.
choice /c 12345 /m "出力ファイルの拡張子を選べ。[1]MP4 [2]M4V [3]MKV [4]MOV [5]その他"
if %errorlevel%==1 set "_output_ext=mp4"
if %errorlevel%==2 set "_output_ext=m4v"
if %errorlevel%==3 set "_output_ext=mkv"
if %errorlevel%==4 set "_output_ext=mov"
if %errorlevel%==5 (
    echo.
    set /p "_output_ext=拡張子を入力せよ (例: webm): "
)
echo 出力拡張子は「.%_output_ext%」じゃな。

echo.
choice /m "音声や字幕など、全てのストリームを保持するか？"
if %errorlevel%==1 (
    set "_keep_all_streams=yes"
    set "_audio_mode=copy"
    echo 全てのストリームを保持するぞ。
    goto :eof
)

echo.
echo 音声の処理方法を選べ。
echo [1] QAACで再エンコード
echo [2] WAV(PCM)に変換
echo [3] そのままコピー (パススルー)
choice /c 123
if %errorlevel%==1 set "_audio_mode=qaac"
if %errorlevel%==2 set "_audio_mode=pcm"
if %errorlevel%==3 set "_audio_mode=copy"

if "%_audio_mode%"=="qaac" (
    echo.
    echo QAACのエンコーダを選べ。
    echo [1] AAC-LC (標準)
    echo [2] HE-AAC (高効率)
    choice /c 12
    if %errorlevel%==1 set "_qaac_profile="
    if %errorlevel%==2 set "_qaac_profile=--he"
)

goto :eof


rem =================================================================
:process_file
rem --- 個別ファイル処理のサブルーチン ---
set "input_file=%~1"
rem 一時フォルダを対象ファイルの場所に作成
set "TEMP_DIR=%~dp1ffmpeg_temp"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

rem --- 出力ファイル名の設定 ---
set "output_name=%~n1"
set "output_ext=%_output_ext%"
rem session.mpdモードでなければ、名前の上書き処理をスキップする
if not "%_session_mpd_mode%"=="yes" goto :skip_rename
rem session.mpdモードの場合、出力ファイル名を親フォルダ名で上書きする
set "parent_path=%~dp1"
set "parent_path=%parent_path:~0,-1%"
for %%N in ("%parent_path%") do set "output_name=%%~nxN"

:skip_rename
set "output_file=%TEMP_DIR%\%output_name%.%output_ext%"
set "temp_audio_file="

echo.
echo --- [!file_count!/%total_files%] "%input_file%" の処理中 ---

rem --- ffmpegコマンドの構築 ---
set "ffmpeg_inputs=-i "%input_file%""
set "ffmpeg_maps="
set "ffmpeg_codecs=-c:v copy"
set "temp_audio_file="

rem 全ストリーム保持かどうかの判定
if "%_keep_all_streams%"=="yes" goto :build_all_streams

rem --- 個別ストリーム処理 ---
if "%_audio_mode%"=="copy" goto :build_audio_copy
if "%_audio_mode%"=="pcm" goto :build_audio_pcm
if "%_audio_mode%"=="qaac" goto :build_audio_qaac
goto :build_audio_copy


:build_all_streams
    set "ffmpeg_maps=-map 0"
    set "ffmpeg_codecs=-c copy"
    goto :build_end

:build_audio_copy
    set "ffmpeg_maps=-map 0:v:0 -map 0:a:0?"
    set "ffmpeg_codecs=%ffmpeg_codecs% -c:a copy"
    goto :build_end

:build_audio_pcm
    set "temp_audio_file=%TEMP_DIR%\%output_name%_temp.wav"
    echo    - 音声をWAVに変換中...
    ffmpeg -hide_banner -y -i "%input_file%" -vn -c:a pcm_s16le "%temp_audio_file%"
    if errorlevel 1 (
        echo    - [エラー] 音声のWAV変換に失敗した。このファイルはスキップする。
        set "_error_occurred=1"
        goto :cleanup_temp
    )
    set "ffmpeg_inputs=%ffmpeg_inputs% -i "%temp_audio_file%""
    set "ffmpeg_maps=-map 0:v:0 -map 1:a:0"
    set "ffmpeg_codecs=%ffmpeg_codecs% -c:a copy"
    goto :build_end

:build_audio_qaac
    set "temp_audio_file=%TEMP_DIR%\%output_name%_temp.m4a"
    echo    - 音声をQAACでエンコード中...
    qaac64.exe %_qaac_profile% "%input_file%" -o "%temp_audio_file%"
    if errorlevel 1 (
        echo    - [エラー] QAACでのエンコードに失敗した。このファイルはスキップする。
        set "_error_occurred=1"
        goto :cleanup_temp
    )
    set "ffmpeg_inputs=%ffmpeg_inputs% -i "%temp_audio_file%""
    set "ffmpeg_maps=-map 0:v:0 -map 1:a:0"
    set "ffmpeg_codecs=%ffmpeg_codecs% -c:a copy"
    goto :build_end


:build_end
rem --- ffmpegの実行 ---
echo     - 映像と音声を結合中...
ffmpeg -hide_banner -y %ffmpeg_inputs% %ffmpeg_maps% %ffmpeg_codecs% -map_chapters -1 "%output_file%"
if errorlevel 1 (
    echo    - [エラー] ffmpegでの最終処理に失敗した。
    set "_error_occurred=1"
) else (
    echo    - 処理成功: "%output_file%"
    
    rem =================================================================
    rem ★★★ ここからが変更箇所 (出力先の変更) ★★★
    rem =================================================================
    rem デフォルトの出力先は入力ファイルと同じ場所
    set "output_dir=%~dp1"
    
    rem session.mpdモードの場合、出力先を入力ファイルの親の親フォルダに変更する
    if "%_session_mpd_mode%"=="yes" (
        rem 入力ファイルの親フォルダを取得 (例: C:\anime\title\)
        set "parent_dir=%~dp1"
        rem 末尾の\を削除 (例: C:\anime\title)
        set "parent_dir=!parent_dir:~0,-1!"
        rem さらにその親フォルダを取得 (例: C:\anime\)
        for %%P in ("!parent_dir!") do set "output_dir=%%~dpP"
        echo    - 出力先を親フォルダ「!output_dir!」に変更したぞ。
    )

    rem 決定した出力先にファイルを移動
    move "%output_file%" "%output_dir%" > nul
    rem =================================================================
    rem ★★★ 変更箇所はここまで ★★★
    rem =================================================================

    rem 元ファイルの削除
    if "%_delete_original%"=="yes" (
        del "%input_file%"
        echo    - 元のファイルを削除したぞ。
    )
)

:cleanup_temp
rem 一時音声ファイルの削除
if exist "%temp_audio_file%" (
    del "%temp_audio_file%"
)
rem 作成した一時フォルダを削除
rmdir "%TEMP_DIR%" >nul 2>nul
goto :eof

:show_help
echo.
echo [概要]
echo   可逆（映像コピー）主体で動画を再パッケージします。session.mpd を検知した場合は固定設定モードで自動処理。
echo.
echo [使い方]
echo   - 通常: %~nx0 ^<file1^> ^<file2^> ...
echo   - フォルダ: %~nx0 ^<folder1^> ^<folder2^> ...  (各フォルダ内の session.mpd を検出)
echo   - mpd直指定: %~nx0 session.mpd
echo.
echo [主なオプション(対話式)]
echo   - 出力拡張子選択 (mp4/m4v/mkv/mov/任意)
echo   - ストリーム保持(全保持) または 音声の個別処理(copy/PCM/QAAC)
echo   - 元ファイル削除の有無
echo.
echo [前提]
echo   ffmpeg, qaac64 が PATH に必要。日本語名対応のため chcp 932 を利用します。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b