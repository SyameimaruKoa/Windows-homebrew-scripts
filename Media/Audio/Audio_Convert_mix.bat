@echo off
setlocal enabledelayedexpansion
rem このバッチのヘルプはファイル末尾にあります（-h / --help または未引数で表示）

rem --- ヘルプ表示（未引数／-h／--help） ---
if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help

rem --- 引数のチェック（最低2ファイル必要） ---
if "%~2"=="" goto :show_help

rem --- 変数の初期化 ---
set "ffmpeg_inputs="
set "filter_streams="
set /a input_count=0

rem --- ループですべての引数を処理し、ffmpegのコマンドを組み立てる ---
for %%F in (%*) do (
    rem ffmpegへの入力部分 (-i "ファイルパス") を追記していく
    set ffmpeg_inputs=!ffmpeg_inputs! -i "%%F"
    
    rem フィルターで使うストリーム指定子 ([0:a][1:a]...) を追記していく
    set filter_streams=!filter_streams![!input_count!:a]
    
    rem 入力ファイルの数を数える
    set /a input_count+=1
)

rem --- 組み立てたコマンドを実行する ---
echo !input_count! 個のファイルをミックスするのじゃ...
rem amixフィルターによる自動音量調整を無効にするため、normalize=false を指定する。
rem これで各ファイルの音量を維持したままミックスされるが、音が割れる可能性もあるので注意じゃ。
ffmpeg !ffmpeg_inputs! -filter_complex "!filter_streams!amix=inputs=!input_count!:duration=longest:normalize=false" -c:a flac "%~n1_mixed.flac"

echo.
echo 処理が終わったぞ。何かキーを押して終了するのじゃ。
pause > nul

goto :eof


:show_help
rem ===================== ヘルプ =====================
echo.
echo [概要]
echo   複数の音声ファイルを等倍でミックスし、1つのFLACファイルに出力します。
echo   音量正規化は行わず（normalize=false^）、各入力の相対音量を維持します。
echo.
echo [使い方]
echo   %~nx0 ^<ベース音声^> ^<混ぜる音声1^> [混ぜる音声2 ...]
echo.
echo [引数]
echo   ベース音声  : 出力ファイル名の元になる先頭の音声ファイル
echo   混ぜる音声x : ミックス対象の追加音声ファイル（2つ以上必須）
echo.
echo [出力]
echo   カレントディレクトリに「^<ベース音声名^>_mixed.flac」を作成します。
echo.
echo [例]
echo   %~nx0 vocal.wav bgm.wav se1.wav
echo     ^> vocal_mixed.flac を出力
echo.
echo [注意]
echo   ・ffmpeg が PATH に通っている必要があります。
echo   ・入力数が多い場合はクリッピング（音割れ）に注意してください。
echo.
echo 何かキーを押すと閉じます...
pause
exit /b
