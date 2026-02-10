@echo off
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）
setlocal enabledelayedexpansion
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
chcp 932 >nul

rem ファイルカウンタ初期化
set filecount=0

rem 複数ファイル処理の判定
if not "%~2"=="" (
    set "multifile=1"
    cd /d "%~dp1"
    if not exist ffmpeg mkdir ffmpeg
) else (
    set "multifile=0"
)

:process_loop
if "%~1"=="" goto :end_process
set /a filecount+=1
cls
echo.
echo ????????????????????????????????????????????????????????
echo   音声トラック抽出ツール
echo ????????????????????????????????????????????????????????
echo.
echo 処理中: %filecount%個目のファイル
echo ファイル: %~nx1
echo.

rem 音声コーデック情報を取得
for /f "tokens=*" %%a in ('ffprobe -v error -select_streams a:0 -show_entries stream^=codec_name -of default^=noprint_wrappers^=1:nokey^=1 "%~1" 2^>nul') do set "codec=%%a"

if not defined codec (
    echo [エラー] 音声トラックが検出されませんでした: %~nx1
    echo.
    shift
    goto :process_loop
)

echo 検出されたコーデック: !codec!
echo.

rem コーデックに応じた拡張子を決定
set "ext="
if /i "!codec!"=="aac" set "ext=m4a"
if /i "!codec!"=="mp3" set "ext=mp3"
if /i "!codec!"=="opus" set "ext=opus"
if /i "!codec!"=="vorbis" set "ext=ogg"
if /i "!codec!"=="flac" set "ext=flac"
if /i "!codec!"=="alac" set "ext=m4a"
if /i "!codec!"=="pcm_s16le" set "ext=wav"
if /i "!codec!"=="pcm_s24le" set "ext=wav"
if /i "!codec!"=="pcm_s32le" set "ext=wav"
if /i "!codec!"=="pcm_f32le" set "ext=wav"
if /i "!codec!"=="pcm_f64le" set "ext=wav"
if /i "!codec!"=="ac3" set "ext=ac3"
if /i "!codec!"=="eac3" set "ext=eac3"
if /i "!codec!"=="dts" set "ext=dts"
if /i "!codec!"=="truehd" set "ext=thd"
if /i "!codec!"=="wmav2" set "ext=wma"
if /i "!codec!"=="ape" set "ext=ape"
if /i "!codec!"=="wavpack" set "ext=wv"
if /i "!codec!"=="tta" set "ext=tta"
if /i "!codec!"=="tak" set "ext=tak"

rem 未対応コーデックの場合はデフォルトでmkaを使用
if not defined ext (
    echo [警告] 未対応のコーデック「!codec!」です。.mka形式で保存します。
    set "ext=mka"
)

rem 出力パスを決定
if "!multifile!"=="1" (
    set "outfile=ffmpeg\%~n1.!ext!"
) else (
    set "outfile=%~dpn1 ffmpeg.!ext!"
)

rem ffmpegで音声抽出
echo 抽出中...
ffmpeg -hide_banner -loglevel error -stats -i "%~1" -vn -c:a copy "!outfile!" 2>&1
if errorlevel 1 (
    echo [エラー] 音声抽出に失敗しました。
    echo.
) else (
    echo 抽出完了: !outfile!
    echo.
    
    rem メタデータコピー（WAV以外）
    if /i not "!ext!"=="wav" (
        echo メタデータをコピー中...
        exiftool -api largefilesupport=1 -tagsfromfile "%~1" -all:all -overwrite_original "!outfile!" 2>nul
        if errorlevel 1 (
            echo [警告] メタデータのコピーに失敗しました（exiftoolが見つかりません）
        ) else (
            echo メタデータコピー完了
        )
        echo.
    )
)

shift
goto :process_loop

:end_process
echo.
echo ????????????????????????????????????????????????????????
echo   処理完了: 合計 %filecount% 個のファイルを処理しました
echo ????????????????????????????????????????????????????????
echo.
pause
exit /b 0

:show_help
echo.
echo ????????????????????????????????????????????????????????
echo   音声トラック抽出ツール（統合版）
echo ????????????????????????????????????????????????????????
echo.
echo [概要]
echo   メディアファイルから第1音声トラックを無変換で抽出します。
echo   コーデックを自動検出し、適切なコンテナ/拡張子で保存します。
echo   メタデータも可能な限りコピーされます（WAVを除く）。
echo.
echo [使い方]
echo   %~nx0 ^<file1^> [file2 file3 ...]
echo.
echo [対応コーデック]
echo   ・AAC/ALAC      -^> .m4a
echo   ・MP3           -^> .mp3
echo   ・Opus          -^> .opus
echo   ・Vorbis        -^> .ogg
echo   ・FLAC          -^> .flac
echo   ・PCM系         -^> .wav
echo   ・AC3           -^> .ac3
echo   ・E-AC3         -^> .eac3
echo   ・DTS           -^> .dts
echo   ・TrueHD        -^> .thd
echo   ・WMA           -^> .wma
echo   ・その他        -^> .mka
echo.
echo [出力先]
echo   ・単一ファイル: 同階層に「^<元ファイル名^> ffmpeg.^<拡張子^>」
echo   ・複数ファイル: 同階層の「ffmpeg\」フォルダに「^<元ファイル名^>.^<拡張子^>」
echo.
echo [必要なツール]
echo   ・ffmpeg, ffprobe （必須）
echo   ・exiftool （メタデータコピー用、オプション）
echo   ※ これらのツールが PATH に通っている必要があります
echo.
echo [例]
echo   %~nx0 video.mp4
echo   %~nx0 video1.mkv video2.mp4 audio.flac
echo.
echo ????????????????????????????????????????????????????????
echo.
pause
exit /b 0
