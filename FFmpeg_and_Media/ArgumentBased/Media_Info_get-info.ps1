param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$filePaths
)

# まずはffprobeかffmpegが使えるか確認するのじゃ
$ffprobePath = Get-Command -Name ffprobe -ErrorAction SilentlyContinue
$ffmpegPath = Get-Command -Name ffmpeg -ErrorAction SilentlyContinue

if (-not $ffprobePath -and -not $ffmpegPath) {
    Write-Host "エラー: ffprobe も ffmpeg も見つからんかったぞ！ Pathが通っているか確認せい！" -ForegroundColor Red
    Read-Host "何かキーを押すと終了する"
    exit
}

foreach ($filePath in $filePaths) {
    if (Test-Path -Path $filePath -PathType Leaf) {
        Write-Host "--- $($filePath) の詳細情報 ---" -ForegroundColor Yellow

        # === 通常情報表示 ===
        Write-Host "[ 通常情報 ]" -ForegroundColor Cyan
        if ($ffprobePath) {
            # ffprobeがあればそちらで表示
            & $ffprobePath.Source -hide_banner -i $filePath
        } else {
            # なければffmpegで代用
            & $ffmpegPath.Source -hide_banner -i $filePath
        }
        Write-Host ""

        # === フレームレート詳細表示 (ffprobeがある場合のみ) ===
        if ($ffprobePath) {
            Write-Host "[ フレームレート詳細 ]" -ForegroundColor Cyan
            # ストリーム情報から分数表記のフレームレートを取得
            $streamInfo = & $ffprobePath.Source -v error -select_streams v:0 -show_entries "stream=r_frame_rate,avg_frame_rate" -of "default=noprint_wrappers=1:nokey=0" -i $filePath
            Write-Host $streamInfo

            # 最初の10フレームの表示時間を調べてVFRかどうかを判断
            Write-Host "--- 最初の10フレームの表示時間(秒) ---"
            $frameDurations = & $ffprobePath.Source -v error -select_streams v:0 -show_entries "frame=duration_time" -of "default=noprint_wrappers=1:nokey=1" -read_intervals "%+#10" -i $filePath
            Write-Host $frameDurations
            Write-Host "(ここの値がバラバラなら、それはVFRじゃ)"
        }
        else {
             Write-Host "[ フレームレート詳細 ]" -ForegroundColor DarkGray
             Write-Host "（ffprobeが見つからんため、このセクションはスキップするのじゃ）"
        }

        Write-Host "======================================================================`n"
    } else {
        Write-Host "エラー: `"$($filePath)`" はファイルではない、または見つからんかったぞ。" -ForegroundColor Red
    }
}

Write-Host "処理が完了したぞ。何かキーを押せば閉じるのじゃ。" -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")