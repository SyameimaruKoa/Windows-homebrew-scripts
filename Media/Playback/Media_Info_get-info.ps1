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
    Shift起動または -FullAnalysis で全編解析します。
    FFplayで元映像・逆テレシネ・Bwdif・両方を比較できるコマンドを表示します。

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

#region 逆テレシネの要否判定

function Show-TelecineAssessment {
    param(
        [string]$File,
        [string]$FFmpegExecutable,
        [string]$FFprobeExecutable,
        [int]$Frames,
        [bool]$Full
    )

    Write-Host ''
    Write-Host '[ プルダウン・逆テレシネ判定（実映像解析） ]' -ForegroundColor Cyan
    if (-not $FFmpegExecutable) {
        Write-Host 'FFmpegがないため解析できないのじゃ。' -ForegroundColor Yellow
        return
    }

    $duration = 0.0
    $fps = 0.0
    if ($FFprobeExecutable) {
        $data = & $FFprobeExecutable -v error -select_streams v:0 -show_entries 'format=duration:stream=avg_frame_rate' -of json -i $File
        if ($LASTEXITCODE -eq 0 -and $data) {
            try {
                $meta = ($data -join [Environment]::NewLine) | ConvertFrom-Json
                if ($meta.format.duration) {
                    $duration = [double]::Parse([string]$meta.format.duration, [Globalization.CultureInfo]::InvariantCulture)
                }
                if ($meta.streams.Count -gt 0) {
                    $fraction = [string]$meta.streams[0].avg_frame_rate
                    if ($fraction -match '^(\d+)/(\d+)$' -and [double]$Matches[2] -ne 0) {
                        $fps = [double]$Matches[1] / [double]$Matches[2]
                    }
                }
            }
            catch {
                Write-Host '再生時間／fpsは取得できなかったため先頭のみ調査するのじゃ。' -ForegroundColor Yellow
            }
        }
    }

    $starts = @(0.0)
    if (-not $Full -and $fps -gt 0 -and $duration -gt ($Frames / $fps) * 2.5) {
        $last = [math]::Max(0.0, $duration - ($Frames / $fps) - 1.0)
        $starts = @(0.0, [math]::Round($last / 2.0, 3), [math]::Round($last, 3))
    }

    $reports = [System.Collections.Generic.List[object]]::new()
    $validStarts = [System.Collections.Generic.List[double]]::new()
    $failed = $false
    if ($Full) {
        Write-Host 'モード: 全編解析' -ForegroundColor Cyan
        $scan = Invoke-CadenceScan -File $File -FFmpegExecutable $FFmpegExecutable -Start 0 -Frames $Frames -Full $true
        if ($scan.Success) {
            foreach ($report in $scan.Reports) { $reports.Add($report) }
            Write-Host "全編 $($scan.FrameCount) フレームを確認したぞ。"
        }
        else {
            $failed = $true
        }
    }
    else {
        Write-Host "モード: 簡易解析（最大$($starts.Count)区間 × $Frames フレーム）" -ForegroundColor Cyan
        $labels = @('冒頭', '中盤', '終盤')
        for ($i = 0; $i -lt $starts.Count; $i++) {
            $start = [double]$starts[$i]
            $label = if ($starts.Count -eq 1) { '冒頭' } else { $labels[$i] }
            $scan = Invoke-CadenceScan -File $File -FFmpegExecutable $FFmpegExecutable -Start $start -Frames $Frames -Full $false
            if ($scan.Success -and $scan.Reports.Count -gt 0) {
                $report = $scan.Reports[0]
                $reports.Add($report)
                $validStarts.Add($start)
                $description = if ($report.Telecine32) { '3:2周期あり' } else { '3:2周期は未検出' }
                $matching = '{0:P0}' -f $report.Consistency
                Write-Host "$label : $description / Top=$($report.Top) / Bottom=$($report.Bottom) / 周期一致=$matching"
            }
            else {
                $failed = $true
                Write-Host "$label : 映像を十分に解析できなかったのじゃ。" -ForegroundColor Yellow
            }
        }
    }

    if ($reports.Count -eq 0) {
        Write-Host '逆テレシネ判定: 判定不能（有効な解析区間なし）' -ForegroundColor Yellow
        return
    }

    $telecine = @($reports | Where-Object { $_.Telecine32 }).Count
    $progressive = @($reports | Where-Object { $_.Classified -ge 20 -and $_.ProgFraction -ge 0.85 }).Count
    $interlaced = @($reports | Where-Object { $_.Classified -ge 20 -and $_.ProgFraction -le 0.15 }).Count
    $top = 0
    $bottom = 0
    foreach ($report in $reports) {
        $top += $report.Top
        $bottom += $report.Bottom
    }
    Write-Host "判定区間=$($reports.Count) / 3:2検出=$telecine / Top反復=$top / Bottom反復=$bottom"
    Write-Host "実映像の傾向: Progressive優勢=$progressive / Interlaced優勢=$interlaced"

    if ($telecine -gt 0) {
        if (-not $failed -and $telecine -eq $reports.Count) {
            Write-Host '逆テレシネ判定: 推奨（全解析区間で3:2周期を検出）' -ForegroundColor Green
            Write-Host '処理候補: fieldmatch,decimate。縞・フレーム欠落は映像でも確認するのじゃ。'
        }
        else {
            Write-Host '逆テレシネ判定: 混在・要確認（一部区間だけ3:2周期を検出）' -ForegroundColor Yellow
            Write-Host '注意: 全編への一律decimateは非3:2部分のコマ落ちにつながり得るぞ。'
        }
        return
    }

    if ($progressive -eq $reports.Count -and $fps -ge 29.5 -and $fps -le 30.1) {
        Write-Host 'プログレッシブ優勢につき、周期的な重複フレームも確認するのじゃ。'
        $duplicateReports = [System.Collections.Generic.List[object]]::new()
        if ($Full) {
            $dup = Invoke-DuplicateScan -File $File -FFmpegExecutable $FFmpegExecutable -Start 0 -Frames $Frames -Full $true
            if ($dup.Success) {
                foreach ($report in $dup.Reports) { $duplicateReports.Add($report) }
            }
            else { $failed = $true }
        }
        else {
            foreach ($start in $validStarts) {
                $dup = Invoke-DuplicateScan -File $File -FFmpegExecutable $FFmpegExecutable -Start $start -Frames $Frames -Full $false
                if ($dup.Success) {
                    foreach ($report in $dup.Reports) { $duplicateReports.Add($report) }
                }
                else { $failed = $true }
            }
        }
        $periodic = @($duplicateReports | Where-Object { $_.Periodic }).Count
        $drops = 0
        $checked = 0
        foreach ($report in $duplicateReports) {
            $drops += $report.Drops
            $checked += $report.Frames
        }
        Write-Host "重複候補=$drops / $checked、5フレーム周期検出=$periodic / $($duplicateReports.Count)"
        if ($failed -or $duplicateReports.Count -eq 0) {
            Write-Host '逆テレシネ判定: 保留（重複解析が不完全）' -ForegroundColor Yellow
        }
        elseif ($periodic -eq $duplicateReports.Count) {
            Write-Host '逆テレシネ判定: フィールド再構成は不要寄り。ただし24p由来の周期重複は除去候補。' -ForegroundColor Yellow
        }
        elseif ($periodic -gt 0) {
            Write-Host '逆テレシネ判定: 保留（区間によって重複周期が異なる）' -ForegroundColor Yellow
        }
        elseif ($drops -le [math]::Max(5, $checked * 0.03)) {
            Write-Host '逆テレシネ判定: 不要寄り（3:2も周期的な重複も見当たらない）' -ForegroundColor Green
        }
        else {
            Write-Host '逆テレシネ判定: 保留（不規則な重複または静止場面）' -ForegroundColor Yellow
        }
        return
    }

    if ($failed) {
        Write-Host '逆テレシネ判定: 保留（解析できなかった区間あり）' -ForegroundColor Yellow
    }
    elseif ($interlaced -eq $reports.Count) {
        Write-Host '逆テレシネ判定: 不要寄り（3:2周期なし、通常インターレースの可能性）' -ForegroundColor Yellow
        Write-Host '注意: デインターレースとは別の処理じゃ。2:2プルダウンは判定保留。'
    }
    else {
        Write-Host '逆テレシネ判定: 保留（3:2周期未検出だが走査方式が不明・混在）' -ForegroundColor Yellow
    }
    Write-Host 'この判定は映像の特徴からの推定であり、全編解析でも完全保証ではないぞ。'
}

#endregion 逆テレシネの要否判定

#region FFplayによるフィルター確認

function Show-FFplayVerification {
    param([string]$VideoPath, [string]$FFprobeExecutable)

    $ffplay = Get-Command ffplay -ErrorAction SilentlyContinue
    if (-not $ffplay) {
        Write-Host 'ffplayが見つからないので再生ボタンは省略する。' -ForegroundColor Yellow
        return
    }
    if ($FFprobeExecutable) {
        $videoStream = & $FFprobeExecutable -v error -select_streams v:0 -show_entries stream=index -of 'csv=p=0' -i $VideoPath
        if ($LASTEXITCODE -eq 0 -and -not $videoStream) { return }
    }

    # Media_Action_play.bat の既定の画面サイズ調整を維持する
    $screenWidth = 1920
    $screenHeight = 1080
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $screenWidth = $area.Width
        $screenHeight = $area.Height
    }
    catch {
        Write-Host '再生ボタンにはWindows Formsが必要。' -ForegroundColor Yellow
        return
    }
    $maxWidth = [math]::Max(64, $screenWidth - 40)
    $maxHeight = [math]::Max(64, $screenHeight - 80)
    $fitScreen = "scale='min($maxWidth,iw)':'min($maxHeight,ih)':force_original_aspect_ratio=decrease"

    # 60i素材ではavg_frame_rateがフィールド側の59.94を示すこともある。
    # そこで冒頭3秒の復号後PTS間隔から実際の入力フレーム頻度を推定する。
    $observedFps = 0.0
    if ($FFprobeExecutable) {
        $ptsLines = @(& $FFprobeExecutable -v error -select_streams v:0 -read_intervals '%+3' -show_entries frame=best_effort_timestamp_time -of 'csv=p=0' -i $VideoPath 2>$null)
        if ($LASTEXITCODE -eq 0 -and $ptsLines.Count -ge 12) {
            $stamps = [System.Collections.Generic.List[double]]::new()
            foreach ($line in $ptsLines) {
                $value = [double]0.0
                if ([double]::TryParse(([string]$line).Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
                    $stamps.Add($value)
                }
            }
            $deltas = [System.Collections.Generic.List[double]]::new()
            for ($i = 1; $i -lt $stamps.Count; $i++) {
                $delta = $stamps[$i] - $stamps[$i - 1]
                if ($delta -gt 0.001 -and $delta -lt 1) { $deltas.Add($delta) }
            }
            if ($deltas.Count -ge 10) {
                $sorted = @($deltas.ToArray() | Sort-Object)
                $medianDelta = [double]$sorted[[int][math]::Floor($sorted.Count / 2)]
                if ($medianDelta -gt 0) { $observedFps = 1.0 / $medianDelta }
            }
        }
    }

    # 確認用フィルターは短く保つ。59.94pと29.97pのBwdifを両方用意。
    $modes = @(
        @{ Name = '1  元映像'; Filter = ''; Rate = 1.0; Bob = $false },
        @{ Name = '2  逆テレシネ'; Filter = 'fieldmatch=order=tff,decimate'; Rate = 0.8; Bob = $false },
        @{ Name = '3  Bwdif（30p系 / send_frame）'; Filter = 'bwdif=mode=send_frame:parity=tff:deint=interlaced'; Rate = 1.0; Bob = $false },
        @{ Name = '4  Bwdif Bob（60p系 / send_field）'; Filter = 'bwdif=mode=send_field:parity=tff:deint=interlaced'; Rate = 2.0; Bob = $true },
        @{ Name = '5  逆テレシネ + Bwdif'; Filter = 'fieldmatch=order=tff:combmatch=full,bwdif=mode=send_frame:parity=tff:deint=interlaced,decimate'; Rate = 0.8; Bob = $false },
        @{ Name = '6  隣接フレームの差分（元映像）'; Filter = 'tblend=all_mode=difference'; Rate = 1.0; Bob = $false },
        @{ Name = '7  隣接フレームの差分（Bob後）'; Filter = 'bwdif=mode=send_field:parity=tff:deint=interlaced,tblend=all_mode=difference'; Rate = 2.0; Bob = $true }
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFplay比較 - ' + [IO.Path]::GetFileName($VideoPath)
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(690, 530)
    $form.MinimumSize = New-Object System.Drawing.Size(690, 530)
    $form.MaximizeBox = $false

    $info = New-Object System.Windows.Forms.Label
    $info.SetBounds(15, 12, 650, 42)
    $inputRateLabel = if ($observedFps -gt 0) {
        '冒頭PTSから推定した入力fps: ' + $observedFps.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
    }
    else { '入力fps: 時刻情報から推定できませんでした' }
    $info.Text = $inputRateLabel + [Environment]::NewLine + '各モードのfpsは推定出力値（実描画FPSではありません）。'
    $form.Controls.Add($info)

    $psQuote = { param([string]$v) "'" + $v.Replace("'", "''") + "'" }
    $index = 0
    foreach ($mode in $modes) {
        $suffix = ''
        if ($observedFps -gt 0) {
            $rateValue = ($observedFps * [double]$mode.Rate).ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
            $suffix = " | 約$rateValue fps"
            if ($mode.Bob) { $suffix += '（i判定時）' }
        }

        $button = New-Object System.Windows.Forms.Button
        $button.SetBounds(15, (68 + $index * 50), 650, 40)
        $button.Text = $mode.Name + $suffix
        $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $button.UseVisualStyleBackColor = $true

        $filter = if ($mode.Filter) { "$($mode.Filter),$fitScreen" } else { $fitScreen }
        $execution = '& ' + (& $psQuote $ffplay.Source) +
            ' -hide_banner -an -sn -window_title ' + (& $psQuote ($mode.Name + $suffix)) +
            ' -vf ' + (& $psQuote $filter) +
            ' -i ' + (& $psQuote $VideoPath)
        $button.Tag = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($execution))
        $button.Add_Click({
            param($sender, $eventArgs)
            # 元のログへffplayの出力を混ぜないよう別ターミナルで起動
            Start-Process -FilePath 'powershell.exe' -ArgumentList ("-NoProfile -EncodedCommand " + [string]$sender.Tag) -WindowStyle Normal
        })
        $form.Controls.Add($button)
        $index++
    }

    $help = New-Object System.Windows.Forms.Label
    $help.SetBounds(15, 426, 650, 55)
    $help.Text = 'S: 1コマ進む　Space: 再生/停止　左右: 10秒移動　Q/Esc: 終了' +
        [Environment]::NewLine +
        '差分は変化が少ないほど暗くなる。静止場面や圧縮ノイズに注意。'
    $form.Controls.Add($help)

    Write-Host ''
    Write-Host '[ FFplay比較ボタン ]' -ForegroundColor Cyan
    Write-Host 'クリックすると別のPowerShellウィンドウでFFplayが起動する。'
    Write-Host '累積フレーム番号は表示しない。fpsは冒頭のPTSからの推定値。'
    [void]$form.ShowDialog()
    $form.Dispose()
}

#endregion FFplayによるフィルター確認

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

            if (-not $SkipCadenceAnalysis) {
                $exe = if ($ffmpegPath) { $ffmpegPath.Source } else { $null }
                Show-TelecineAssessment -File $filePath -FFmpegExecutable $exe -FFprobeExecutable $ffprobePath.Source -Frames $AnalysisFrames -Full $runFullAnalysis
            }

        }
        else {
            Write-Host "[ フレームレート詳細 ]" -ForegroundColor DarkGray
            Write-Host "（ffprobeが見つからんため、このセクションはスキップするのじゃ）"
            Write-Host "[ 走査方式 ]" -ForegroundColor DarkGray
            Write-Host "（ffprobeが見つからんため、このセクションはスキップするのじゃ）"
            if (-not $SkipCadenceAnalysis) {
                $exe = if ($ffmpegPath) { $ffmpegPath.Source } else { $null }
                Show-TelecineAssessment -File $filePath -FFmpegExecutable $exe -FFprobeExecutable $null -Frames $AnalysisFrames -Full $runFullAnalysis
            }
        }

        Show-FFplayVerification -VideoPath $filePath -FFprobeExecutable $(if ($ffprobePath) { $ffprobePath.Source } else { $null })

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