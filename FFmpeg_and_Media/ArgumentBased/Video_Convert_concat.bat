@echo off
chcp 932
setlocal enabledelayedexpansion

choice /m "出力先を固定しますか？（固定する場合は「C:\Users\kouki\Videos\エンコード済み」に保存されます）"
if %errorlevel%==1 set outputpath=fixed

if "%outputpath%"=="fixed" (
cd "C:\Users\kouki\Videos\エンコード済み"
) else (
%~d1
cd "%~dp1"
)

rem --- 第1段階: ドラッグ&ドロップされたファイルから仮のリストを作成 ---
rem 以前の一時ファイルが残っていたら削除する
if exist "connect.txt" del "connect.txt"

echo ドラッグされたファイルからリストを作成中...
FOR %%F IN (%*) DO (
    rem ffmpegが要求する 'file' 形式でファイルパスを書き込む
    echo file '%%~dpnxF' >> connect.txt
)

:CONFIRM_CONNECT
echo. & echo 【段階１】ファイル順の確認
echo 以下の順番でファイルを連結する。
echo =================================================================
if exist "connect.txt" type "connect.txt"
echo =================================================================
echo.
set "choice1="
choice /m "この順番でよろしいか？"
if not %errorlevel%==1 (
    echo メモ帳で connect.txt を編集するのじゃ。終わったら上書き保存して閉じること。
    start /wait notepad "connect.txt"
    goto :CONFIRM_CONNECT
)

rem --- 第2段階: チャプター情報の生成と、ユーザーによる確認・編集 ---
echo. & echo -----------------------------------------------------------------
echo. & echo 【段階２】チャプター情報の生成と確認
echo 最終的なファイルリストに基づき、チャプター情報を自動生成する...

if exist "metadata.txt" del "metadata.txt"
(echo ;FFMETADATA1) > metadata.txt
set total_duration_ms=0

FOR /F "usebackq tokens=2 delims='" %%P IN ("connect.txt") DO (
    set "duration_s=0"
    set "duration_f=0"
    for /f "tokens=1,2 delims=." %%A in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "%%P"') do (
        set "duration_s=%%A"
        set "duration_f=%%B"
    )

    rem ★★★ここが最後の修正箇所じゃ！★★★
    rem 最初にダミーの計算を試みて、入力値が有効な数字か判定する。エラーは表示しない(2^>nul)
    set /a "test_calc=!duration_s!*1" 2>nul
    
    if !errorlevel! equ 0 (
        rem 計算が成功した場合(有効な数字だった場合)のみ、本番の処理を行う
        if "!duration_s!"=="" set "duration_s=0"
        
        set "temp_f=!duration_f!000"
        set "temp_f=!temp_f:~0,3!"

        set /a "final_f=1*!temp_f!"
        set /a "duration_ms=!duration_s! * 1000 + !final_f!"

        if !duration_ms! gtr 0 (
            (echo [CHAPTER] & echo TIMEBASE=1/1000 & echo START=!total_duration_ms! & set /a end_ms=!total_duration_ms!+!duration_ms! & echo END=!end_ms! & echo title=%%~nP) >> metadata.txt
            set /a total_duration_ms=!end_ms!
        )
    ) else (
        echo [警告] ファイル "%%~nP" の再生時間を取得・計算できなかったため、チャプター生成をスキップするのじゃ。
    )
)

:CONFIRM_METADATA
echo. & echo 【段階２】チャプター情報の確認
echo 以下の内容でチャプターを作成する。
echo =================================================================
if exist "metadata.txt" type "metadata.txt"
echo =================================================================
echo.
choice /m "この内容でよろしいか？"
if not %errorlevel%==1 (
    echo メモ帳で metadata.txt を編集するのじゃ。再生時間はミリ秒単位じゃぞ。
    echo 1チャプター
    echo "[CHAPTER]"
    echo "TIMEBASE=1/1000"
    echo "START=0"
    echo "END=210337"
    echo "title=20250510_193008"
    echo 最初のチャプターは、必ず START=0 で始めること。
    echo 次のチャプターの START は、必ず前のチャプターの END と同じ数値にすること。 これがズレると、動画の途中に隙間ができたり、チャプターが重なったりする。
    echo "時間はすべてミリ秒で書くこと。（例： 2分15秒500ミリ秒 → (2 * 60 + 15) * 1000 + 500 → 135500）"
    start /wait notepad "metadata.txt"
    goto :CONFIRM_METADATA
)
rem --- 第3段階: 最終実行 ---
echo. & echo -----------------------------------------------------------------
echo. & echo 【段階３】最終実行
echo いよいよ連結を開始する...
ffmpeg -hide_banner -f concat -safe 0 -i connect.txt -i metadata.txt -map_chapters -1 -map_metadata 1 -c copy "%~n1_merged_chapters_manual%~x1"

rem --- 後始末 ---
if %errorlevel%==0 (
    del "connect.txt"
    del "metadata.txt"
)

echo.
echo 処理が完了したぞ。
pause
endlocal