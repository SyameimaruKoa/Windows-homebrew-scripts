@echo off
setlocal enabledelayedexpansion

rem --- 引数のチェック ---
if "%~2"=="" (
    echo ミックスするファイルが2つ以上指定されておらんぞ！
    echo ベースとなるファイルを先頭にして、複数のファイルを指定するのじゃ。
    pause
    exit /b
)

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
