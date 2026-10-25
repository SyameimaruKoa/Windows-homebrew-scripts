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
    FFmpegで複数区間の3:2プルダウン周期を解析し、逆テレシネの要否を推定します。
    Shift起動または -FullAnalysis で全編解析します。GPUデコードは使用しません。

.PARAMETER filePaths
    情報を表示したいメディアファイルのパスを1つ以上指定します。

.PARAMETER AnalysisFrames
    通常解析で各区間から調べるフレーム数（既定180、60～1200）。

.PARAMETER FullAnalysis
    Shift起動と同様に全編解析を有効化します。

.PARAMETER SkipCadenceAnalysis
    負荷の大きい実映像解析をスキップします。

.PARAMETER Help
    詳細な使い方を表示します。-h も使用できます。

.EXAMPLE
    PS> .\Media_Info_get-info.ps1 video.mp4 audio.m4a
    2つのファイルの一般情報と、可能であればフレームレート詳細を表示します。

.EXAMPLE
    PS> .\Media_Info_get-info.ps1 -FullAnalysis '.\動画[01].m2ts'
    全フレームを解析します。

.EXAMPLE
    PS> .\Media_Info_get-info.ps1 -AnalysisFrames 300 '.\動画[01].mkv'
    冒頭・中盤・終盤を各300フレーム解析します。

.EXAMPLE
    PS> .\Media_Info_get-info.ps1 -SkipCadenceAnalysis '.\動画[01].mkv'
    旧来の高速な情報表示だけを行います。

.EXAMPLE
    PS> .\Media_Info_get-info.ps1 -h
    ヘルプを表示します。

.NOTES
    ・ffprobe または ffmpeg が PATH に通っている必要があります。
    ・ドラッグ＆ドロップでも実行できます。
    ・Shiftを押したまま起動すると全編解析します。
    ・判定はあくまで映像からの推定です。2:2などの完全判定は対象外です。
#>
#endregion

param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$filePaths,

    [ValidateRange(60, 1200)]
    [int]$AnalysisFrames = 180,

    [switch]$FullAnalysis,

    [switch]$SkipCadenceAnalysis,

    [Alias('h')]
    [switch]$Help
)

if ($Help -or -not $filePaths -or $filePaths.Count -eq 0) {
    Get-Help -Name $PSCommandPath -Detailed
    return
}

# 起動直後にShift状態を検出。押し続けられない場合は -FullAnalysis で代用できる。
$runFullAnalysis = [bool]$FullAnalysis
if (-not $runFullAnalysis) {
    try {
        if (-not ('MediaInfoKeyboard' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MediaInfoKeyboard {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKey);
}
'@ -ErrorAction Stop
        }
        $runFullAnalysis = (([MediaInfoKeyboard]::GetAsyncKeyState(0x10) -band 0x8000) -ne 0)
    }
    catch {
        # Windows以外ではShift検出を省略する
    }
}

#region 3:2プルダウン解析

function New-CadenceChunk {
    return [pscustomobject]@{
        Frames = 0
        Top = [System.Collections.Generic.List[int]]::new()
        Bottom = [System.Collections.Generic.List[int]]::new()
        Progressive = 0
        Interlaced = 0
        Unknown = 0
    }
}

function Get-PeriodicPhase {
    param([int[]]$Positions)

    if (-not $Positions -or $Positions.Count -eq 0) {
        return [pscustomobject]@{ Phase = -1; Match = 0.0 }
    }
    $histogram = @(0, 0, 0, 0, 0)
    foreach ($position in $Positions) {
        $histogram[$position % 5]++
    }
    $best = 0
    for ($i = 1; $i -lt 5; $i++) {
        if ($histogram[$i] -gt $histogram[$best]) {
            $best = $i
        }
    }
    return [pscustomobject]@{
        Phase = $best
        Match = ($histogram[$best] / [double]$Positions.Count)
    }
}

function Complete-CadenceChunk {
    param($Chunk)

    $top = $Chunk.Top.Count
    $bottom = $Chunk.Bottom.Count
    $repeats = $top + $bottom
    $phaseTop = Get-PeriodicPhase -Positions $Chunk.Top.ToArray()
    $phaseBottom = Get-PeriodicPhase -Positions $Chunk.Bottom.ToArray()
    $consistency = if ($repeats -gt 0) {
        ($top * $phaseTop.Match + $bottom * $phaseBottom.Match) / $repeats
    }
    else {
        0.0
    }
    $gap = ($phaseBottom.Phase - $phaseTop.Phase + 5) % 5
    $repeatRatio = if ($Chunk.Frames -gt 0) { $repeats / [double]$Chunk.Frames } else { 0.0 }
    $classified = $Chunk.Progressive + $Chunk.Interlaced
    $progFraction = if ($classified -gt 0) { $Chunk.Progressive / [double]$classified } else { 0.0 }
    return [pscustomobject]@{
        Frames = $Chunk.Frames
        Top = $top
        Bottom = $bottom
        Consistency = $consistency
        Progressive = $Chunk.Progressive
        Interlaced = $Chunk.Interlaced
        Unknown = $Chunk.Unknown
        Classified = $classified
        ProgFraction = $progFraction
        Telecine32 = (
            $Chunk.Frames -ge 50 -and
            $top -ge 4 -and
            $bottom -ge 4 -and
            $repeatRatio -ge 0.10 -and
            $repeatRatio -le 0.55 -and
            $consistency -ge 0.85 -and
            $gap -in @(2, 3)
        )
    }
}

# 全編解析時は300フレームごとに集計し、ログをメモリに蓄積しない
function Invoke-CadenceScan {
    param(
        [string]$File,
        [string]$FFmpegExecutable,
        [double]$Start,
        [int]$Frames,
        [bool]$Full
    )

    $maxChunk = if ($Full) { 300 } else { $Frames }
    $state = [pscustomobject]@{
        Chunk = (New-CadenceChunk)
        Reports = [System.Collections.Generic.List[object]]::new()
        FrameCount = [long]0
    }
    $arguments = @('-hide_banner', '-loglevel', 'info', '-nostats', '-nostdin')
    if (-not $Full -and $Start -gt 0) {
        $arguments += @('-ss', $Start.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture))
    }
    $arguments += @(
        '-i', $File, '-map', '0:v:0',
        '-vf', 'idet,metadata=mode=print:key=lavfi.idet.repeated.current_frame,metadata=mode=print:key=lavfi.idet.multiple.current_frame'
    )
    if (-not $Full) {
        $arguments += @('-frames:v', [string]$Frames)
    }
    $arguments += @('-an', '-sn', '-dn', '-f', 'null', 'NUL')

    & $FFmpegExecutable @arguments 2>&1 | ForEach-Object {
        $line = [string]$_
        if ($line -match 'lavfi\.idet\.repeated\.current_frame=(neither|top|bottom)') {
            # 前のフレームの分類が届いてから区間を確定する
            if ($state.Chunk.Frames -ge $maxChunk) {
                $state.Reports.Add((Complete-CadenceChunk -Chunk $state.Chunk))
                $state.Chunk = New-CadenceChunk
            }
            if ($Matches[1] -eq 'top') {
                $state.Chunk.Top.Add([int]$state.Chunk.Frames)
            }
            elseif ($Matches[1] -eq 'bottom') {
                $state.Chunk.Bottom.Add([int]$state.Chunk.Frames)
            }
            $state.Chunk.Frames++
            $state.FrameCount++
            if ($Full -and ($state.FrameCount % 900 -eq 0)) {
                Write-Progress -Activity '全編のプルダウン周期を解析中' -Status "$($state.FrameCount) フレーム完了"
            }
        }
        elseif ($line -match 'lavfi\.idet\.multiple\.current_frame=(tff|bff|progressive|undetermined)') {
            switch ($Matches[1]) {
                'progressive' { $state.Chunk.Progressive++; break }
                'tff' { $state.Chunk.Interlaced++; break }
                'bff' { $state.Chunk.Interlaced++; break }
                default { $state.Chunk.Unknown++; break }
            }
        }
    }
    $scanExitCode = $LASTEXITCODE
    if ($Full) {
        Write-Progress -Activity '全編のプルダウン周期を解析中' -Completed
    }
    if ($state.Chunk.Frames -gt 0) {
        $state.Reports.Add((Complete-CadenceChunk -Chunk $state.Chunk))
    }
    return [pscustomobject]@{
        Success = ($scanExitCode -eq 0 -and $state.FrameCount -ge 50)
        ExitCode = $scanExitCode
        FrameCount = $state.FrameCount
        Reports = @($state.Reports.ToArray() | Where-Object { $_.Frames -ge 50 })
    }
}

#endregion 3:2プルダウン解析

#region プログレッシブ映像の重複フレーム解析

function New-DuplicateChunk {
    return [pscustomobject]@{
        Frames = 0
        Drops = [System.Collections.Generic.List[int]]::new()
    }
}

function Complete-DuplicateChunk {
    param($Chunk)

    $phase = Get-PeriodicPhase -Positions $Chunk.Drops.ToArray()
    $fraction = if ($Chunk.Frames -gt 0) {
        $Chunk.Drops.Count / [double]$Chunk.Frames
    }
    else {
        0.0
    }
    return [pscustomobject]@{
        Frames = $Chunk.Frames
        Drops = $Chunk.Drops.Count
        Periodic = (
            $Chunk.Frames -ge 50 -and
            $Chunk.Drops.Count -ge 6 -and
            $fraction -ge 0.10 -and
            $fraction -le 0.35 -and
            $phase.Match -ge 0.80
        )
        Match = $phase.Match
    }
}

function Invoke-DuplicateScan {
    param(
        [string]$File,
        [string]$FFmpegExecutable,
        [double]$Start,
        [int]$Frames,
        [bool]$Full
    )

    $maxChunk = if ($Full) { 300 } else { $Frames }
    $state = [pscustomobject]@{
        Chunk = (New-DuplicateChunk)
        Reports = [System.Collections.Generic.List[object]]::new()
        FrameCount = [long]0
    }
    $arguments = @('-hide_banner', '-loglevel', 'debug', '-nostats', '-nostdin')
    if (-not $Full -and $Start -gt 0) {
        $arguments += @('-ss', $Start.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture))
    }
    $filter = if ($Full) { 'mpdecimate' } else { "trim=end_frame=$Frames,mpdecimate" }
    $arguments += @('-i', $File, '-map', '0:v:0', '-vf', $filter, '-an', '-sn', '-dn', '-f', 'null', 'NUL')

    & $FFmpegExecutable @arguments 2>&1 | ForEach-Object {
        $line = [string]$_
        if ($line -match '\[Parsed_mpdecimate_[^\]]+\].*\b(drop|keep)\s+pts:') {
            if ($state.Chunk.Frames -ge $maxChunk) {
                $state.Reports.Add((Complete-DuplicateChunk -Chunk $state.Chunk))
                $state.Chunk = New-DuplicateChunk
            }
            if ($Matches[1] -eq 'drop') {
                $state.Chunk.Drops.Add([int]$state.Chunk.Frames)
            }
            $state.Chunk.Frames++
            $state.FrameCount++
            if ($Full -and ($state.FrameCount % 900 -eq 0)) {
                Write-Progress -Activity '全編の重複フレームを解析中' -Status "$($state.FrameCount) フレーム完了"
            }
        }
    }
    $scanExitCode = $LASTEXITCODE
    if ($Full) {
        Write-Progress -Activity '全編の重複フレームを解析中' -Completed
    }
    if ($state.Chunk.Frames -gt 0) {
        $state.Reports.Add((Complete-DuplicateChunk -Chunk $state.Chunk))
    }
    return [pscustomobject]@{
        Success = ($scanExitCode -eq 0 -and $state.FrameCount -ge 50)
        ExitCode = $scanExitCode
        FrameCount = $state.FrameCount
        Reports = @($state.Reports.ToArray() | Where-Object { $_.Frames -ge 50 })
    }
}

#endregion プログレッシブ映像の重複フレーム解析

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

Write-Host "処理が完了したぞ。Enterキーを押せば閉じるのじゃ。" -ForegroundColor Green
# CtrlキーやCtrl+Cで閉じないように、Enterのキーダウンだけを終了条件とする
do {
    $pressedKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
} while ($pressedKey.VirtualKeyCode -ne 13)