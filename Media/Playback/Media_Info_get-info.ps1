#region ヘルプ
<#
.SYNOPSIS
    メディアファイルの情報を表示します（ffprobe/ffmpegを使用）。

.DESCRIPTION
    指定したメディアファイルごとに、一般情報（hide_banner出力）を表示します。
    ffprobe が利用可能な場合は、r_frame_rate と avg_frame_rate の詳細、
    さらに先頭10フレームの表示時間からVFR傾向の目安も併せて表示します。
    また、映像の走査方式（インターレース／プログレッシブ）とフィールド順、
    先頭10フレームの走査方式フラグも表示します。

.PARAMETER filePaths
    情報を表示したいメディアファイルのパスを1つ以上指定します。

.EXAMPLE
    PS> .\Media_Info_get-info.ps1 video.mp4 audio.m4a
    2つのファイルの一般情報と、可能であればフレームレート詳細を表示します。

.NOTES
    ・ffprobe または ffmpeg が PATH に通っている必要があります。
    ・ドラッグ＆ドロップでも実行できます。
#>
#endregion

param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
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
    if (Test-Path -LiteralPath $filePath -PathType Leaf) {
        Write-Host "--- $($filePath) の詳細情報 ---" -ForegroundColor Yellow

        # === 通常情報表示 ===
        Write-Host "[ 通常情報 ]" -ForegroundColor Cyan
        if ($ffprobePath) {
            # ffprobeがあればそちらで表示
            & $ffprobePath.Source -hide_banner -i $filePath
        }
        else {
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

            # === 走査方式（インターレース／プログレッシブ） ===
            Write-Host ""
            Write-Host "[ 走査方式 ]" -ForegroundColor Cyan
            # ストリームのフィールド順と、先頭10フレームの走査方式フラグを取得
            $scanInfoJson = & $ffprobePath.Source -v error -select_streams v:0 -show_entries "stream=field_order:frame=interlaced_frame,top_field_first" -read_intervals "%+#10" -of json -i $filePath
            $scanInfo = $null
            if ($LASTEXITCODE -eq 0 -and $scanInfoJson) {
                try {
                    $scanInfo = ($scanInfoJson -join "`n") | ConvertFrom-Json
                }
                catch {
                    Write-Host "走査方式の解析に失敗したのじゃ。" -ForegroundColor Yellow
                }
            }

            if ($scanInfo -and $scanInfo.streams -and $scanInfo.streams.Count -gt 0) {
                $fieldOrder = [string]$scanInfo.streams[0].field_order
                switch ($fieldOrder) {
                    "progressive" { $streamScan = "プログレッシブ"; break }
                    "tt"          { $streamScan = "インターレース（TFF：トップフィールド優先）"; break }
                    "bb"          { $streamScan = "インターレース（BFF：ボトムフィールド優先）"; break }
                    "tb"          { $streamScan = "インターレース（TB：上位フィールドを先に符号化、下位を先に表示）"; break }
                    "bt"          { $streamScan = "インターレース（BT：下位フィールドを先に符号化、上位を先に表示）"; break }
                    default       { $streamScan = "不明"; break }
                }
                if (-not $fieldOrder) { $fieldOrder = "unknown" }
                Write-Host "ストリーム情報: $streamScan (field_order=$fieldOrder)"

                $flaggedFrames = @($scanInfo.frames | Where-Object { $null -ne $_ -and $null -ne $_.interlaced_frame })
                if ($flaggedFrames.Count -gt 0) {
                    $interlacedCount = @($flaggedFrames | Where-Object { $_.interlaced_frame -eq 1 }).Count
                    $progressiveCount = @($flaggedFrames | Where-Object { $_.interlaced_frame -eq 0 }).Count
                    Write-Host "先頭$($flaggedFrames.Count)フレーム: インターレース $interlacedCount / プログレッシブ $progressiveCount"

                    if ($interlacedCount -gt 0) {
                        $tffCount = @($flaggedFrames | Where-Object { $_.interlaced_frame -eq 1 -and $_.top_field_first -eq 1 }).Count
                        $bffCount = @($flaggedFrames | Where-Object { $_.interlaced_frame -eq 1 -and $_.top_field_first -eq 0 }).Count
                        Write-Host "インターレースフレームのフィールド順: TFF $tffCount / BFF $bffCount"
                    }
                    if (($fieldOrder -eq "progressive" -and $interlacedCount -gt 0) -or
                        ($fieldOrder -in @("tt", "bb", "tb", "bt") -and $progressiveCount -gt 0)) {
                        Write-Host "注意: ストリーム情報とフレームのフラグに差異があるのじゃ。" -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "フレーム単位の走査方式フラグは取得できなかったのじゃ。"
                }
            }
            else {
                Write-Host "映像ストリームがないか、走査方式の情報を取得できなかったのじゃ。"
            }
            Write-Host "（これはメタデータ／デコード時のフラグで、映像内の縞模様を実測した結果ではないぞ）"

        }
        else {
            Write-Host "[ フレームレート詳細 ]" -ForegroundColor DarkGray
            Write-Host "（ffprobeが見つからんため、このセクションはスキップするのじゃ）"
            Write-Host "[ 走査方式 ]" -ForegroundColor DarkGray
            Write-Host "（ffprobeが見つからんため、このセクションはスキップするのじゃ）"
        }

        Write-Host "======================================================================`n"
    }
    else {
        Write-Host "エラー: `"$($filePath)`" はファイルではない、または見つからんかったぞ。" -ForegroundColor Red
    }
}

Write-Host "処理が完了したぞ。何かキーを押せば閉じるのじゃ。" -ForegroundColor Green
[void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")