#region ヘルプ
<#
.SYNOPSIS
    現在のWi-Fi接続情報を定期表示します。（残像除去版）

.DESCRIPTION
    netsh wlan show interfaces コマンドの出力を指定間隔で更新し続けます。
    ちらつき対策として画面クリア連打は行わず、カーソル制御で上書き表示します。
    また、各行をウィンドウ幅まで空白で埋めることで残像を防ぎます。

.PARAMETER Interval
    更新間隔（秒）を指定します。既定値は1秒です。
    1〜3600の整数を指定できます。

.PARAMETER Help
    このヘルプを表示します。

.EXAMPLE
    .\WiFi_Get-Info.ps1
    Wi-Fi情報の表示を開始します。

.EXAMPLE
    .\WiFi_Get-Info.ps1 -Interval 2
    2秒間隔でWi-Fi情報を更新表示します。
#>
#endregion

param(
    [Parameter(HelpMessage = "更新間隔を秒単位で指定します（デフォルト: 1）")]
    [ValidateRange(1, 3600)]
    [int]$Interval = 1,

    [Parameter(HelpMessage = "ヘルプを表示します。")]
    [Alias('h')]
    [switch]$Help
)

# --help 指定にも対応
if ($args -contains '--help') {
    $Help = $true
}

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# --- ウィンドウサイズの最適化 ---
try {
    $targetWidth = 135
    $targetHeight = 40

    $rawUI = $Host.UI.RawUI
    $bufSize = $rawUI.BufferSize
    $winSize = $rawUI.WindowSize

    if ($bufSize.Width -lt $targetWidth) { $bufSize.Width = $targetWidth }
    if ($bufSize.Height -lt 3000) { $bufSize.Height = 3000 }
    $rawUI.BufferSize = $bufSize

    $winSize.Width = $targetWidth
    if ($winSize.Height -lt $targetHeight) { $winSize.Height = $targetHeight }
    $rawUI.WindowSize = $winSize
}
catch {
    Write-Host "画面サイズの変更に失敗しましたが、処理は続行します。" -ForegroundColor Yellow
}

Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Wi-Fi情報を $($Interval) 秒おきに更新表示します。" -ForegroundColor Cyan
Write-Host "残像対策のため、カーソル制御と行末パディングで描画します。" -ForegroundColor Cyan
Write-Host "終了するには Ctrl+C を押してください。" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Start-Sleep -Seconds 2
Clear-Host

function Get-DisplayWidth {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return 0
    }

    $width = 0
    $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($Text)
    while ($enumerator.MoveNext()) {
        $element = [string]$enumerator.Current
        $codePoint = [char]::ConvertToUtf32($element, 0)

        $isWide =
        ($codePoint -ge 0x1100 -and $codePoint -le 0x115F) -or
        ($codePoint -ge 0x2E80 -and $codePoint -le 0xA4CF) -or
        ($codePoint -ge 0xAC00 -and $codePoint -le 0xD7A3) -or
        ($codePoint -ge 0xF900 -and $codePoint -le 0xFAFF) -or
        ($codePoint -ge 0xFE10 -and $codePoint -le 0xFE6F) -or
        ($codePoint -ge 0xFF00 -and $codePoint -le 0xFF60) -or
        ($codePoint -ge 0xFFE0 -and $codePoint -le 0xFFE6)

        if ($isWide) {
            $width += 2
        }
        else {
            $width += 1
        }
    }

    return $width
}

function Format-LineForWidth {
    param(
        [string]$Text,
        [int]$MaxWidth
    )

    if ($null -eq $Text) {
        $Text = ''
    }

    if ($MaxWidth -lt 1) {
        return ''
    }

    $clean = $Text.TrimEnd("`r", "`n")
    $result = ''
    $currentWidth = 0

    $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($clean)
    while ($enumerator.MoveNext()) {
        $element = [string]$enumerator.Current
        $codePoint = [char]::ConvertToUtf32($element, 0)

        $charWidth = if (
            ($codePoint -ge 0x1100 -and $codePoint -le 0x115F) -or
            ($codePoint -ge 0x2E80 -and $codePoint -le 0xA4CF) -or
            ($codePoint -ge 0xAC00 -and $codePoint -le 0xD7A3) -or
            ($codePoint -ge 0xF900 -and $codePoint -le 0xFAFF) -or
            ($codePoint -ge 0xFE10 -and $codePoint -le 0xFE6F) -or
            ($codePoint -ge 0xFF00 -and $codePoint -le 0xFF60) -or
            ($codePoint -ge 0xFFE0 -and $codePoint -le 0xFFE6)
        ) { 2 } else { 1 }

        if (($currentWidth + $charWidth) -gt $MaxWidth) {
            break
        }

        $result += $element
        $currentWidth += $charWidth
    }

    if ($currentWidth -lt $MaxWidth) {
        $result += (' ' * ($MaxWidth - $currentWidth))
    }

    return $result
}

function Ensure-WindowSizeForFrame {
    param(
        [string[]]$Lines,
        [int]$MinimumHeight = 20,
        [int]$MinimumWidth = 100
    )

    try {
        $rawUI = $Host.UI.RawUI
        $maxWindow = $rawUI.MaxPhysicalWindowSize
        if ($maxWindow.Width -lt 1 -or $maxWindow.Height -lt 1) {
            $maxWindow = $rawUI.MaxWindowSize
        }

        $requiredWidth = $MinimumWidth
        foreach ($line in $Lines) {
            $lineWidth = Get-DisplayWidth -Text ([string]$line)
            if ($lineWidth -gt $requiredWidth) {
                $requiredWidth = $lineWidth
            }
        }

        # 端での自動改行を避けるために少し余白を持たせる
        $requiredWidth += 8
        $requiredWidth = [Math]::Min($requiredWidth, $maxWindow.Width)
        $requiredWidth = [Math]::Max(20, $requiredWidth)

        $requiredHeight = [Math]::Max($MinimumHeight, $Lines.Count + 2)
        $requiredHeight = [Math]::Min($requiredHeight, $maxWindow.Height)
        $requiredHeight = [Math]::Max(5, $requiredHeight)

        $bufferSize = $rawUI.BufferSize
        $windowSize = $rawUI.WindowSize

        # 幅を縮める必要がある場合は Window -> Buffer の順で適用
        if ($windowSize.Width -gt $requiredWidth) {
            $windowSize.Width = $requiredWidth
            $rawUI.WindowSize = $windowSize
        }

        if ($bufferSize.Width -ne $requiredWidth) {
            $bufferSize.Width = [Math]::Max($requiredWidth, $rawUI.WindowSize.Width)
        }

        $targetBufferHeight = [Math]::Max($requiredHeight + 10, 300)
        if ($bufferSize.Height -lt $targetBufferHeight) {
            $bufferSize.Height = $targetBufferHeight
        }

        $rawUI.BufferSize = $bufferSize

        $windowSize = $rawUI.WindowSize
        if ($windowSize.Width -ne $requiredWidth) {
            $windowSize.Width = $requiredWidth
        }
        if ($windowSize.Height -ne $requiredHeight) {
            $windowSize.Height = $requiredHeight
        }

        $rawUI.WindowSize = $windowSize
    }
    catch {
        # リサイズ不可環境（例: 一部ターミナル）でも表示処理は継続
    }
}

# --- Wi-Fi情報表示ループ（ちらつき対策・残像除去版）---
$previousBodyLineCount = 0
while ($true) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $headerTitle = "[$timestamp] Wi-Fi Interface Status (Clean View)"

    # netshをUTF-8コードページ経由で実行して文字化けを回避
    $wifiLines = cmd /d /c "chcp 65001>nul & netsh wlan show interfaces" 2>&1
    $currentBodyLineCount = $wifiLines.Count

    $cleanupLines = [Math]::Max(5, $previousBodyLineCount - $currentBodyLineCount)
    $previewLines = @($headerTitle, ("=" * 40)) + @($wifiLines | ForEach-Object { [string]$_ }) + @(("=" * 40))

    Ensure-WindowSizeForFrame -Lines $previewLines -MinimumHeight ($previewLines.Count + $cleanupLines + 2) -MinimumWidth 100

    $currentWidth = [Math]::Max(20, $Host.UI.RawUI.WindowSize.Width - 6)
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)

    $frameLines = New-Object System.Collections.Generic.List[string]
    $frameLines.Add((Format-LineForWidth -Text $headerTitle -MaxWidth $currentWidth))
    $frameLines.Add((Format-LineForWidth -Text ("=" * 40) -MaxWidth $currentWidth))

    foreach ($line in $wifiLines) {
        $text = [string]$line
        $text = Format-LineForWidth -Text $text -MaxWidth $currentWidth
        $frameLines.Add($text)
    }

    $frameLines.Add((Format-LineForWidth -Text ("=" * 40) -MaxWidth $currentWidth))

    # 前回より行数が減った場合だけ余剰行を確実に消去
    for ($i = 0; $i -lt $cleanupLines; $i++) {
        $frameLines.Add((" " * $currentWidth))
    }

    Write-Host ($frameLines -join [Environment]::NewLine)

    $previousBodyLineCount = $currentBodyLineCount

    Start-Sleep -Seconds $Interval
}
