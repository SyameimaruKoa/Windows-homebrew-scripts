<#
末尾にコメントベースのヘルプがあるのじゃ。
#>

#region Parameters
param (
    [string[]]$TargetSSIDs,
    [string]$ExitNodeIP,
    [switch]$h,
    [switch]$help
)
#endregion

#region Help Check
if ($h -or $help -or $null -eq $TargetSSIDs -or $TargetSSIDs.Count -eq 0 -or [string]::IsNullOrWhiteSpace($ExitNodeIP)) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}
#endregion

#region Logging
$logDirectory = Join-Path $env:ProgramData 'Windows-homebrew-scripts\Logs'
try {
    [void][System.IO.Directory]::CreateDirectory($logDirectory)
    $logFile = Join-Path $logDirectory 'Set-TailscaleExitNode.log'
    Add-Content -LiteralPath $logFile -Value '' -Encoding UTF8 -ErrorAction Stop
}
catch {
    $logDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'Windows-homebrew-scripts'
    [void][System.IO.Directory]::CreateDirectory($logDirectory)
    $logFile = Join-Path $logDirectory 'Set-TailscaleExitNode.log'
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try {
        Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "ログへの書き込みに失敗したのじゃ: $_"
    }
}
#endregion

#region External Commands
function Invoke-ExternalCommand {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$Label,
        [int]$TimeoutSeconds = 15,
        [System.Text.Encoding]$OutputEncoding = [System.Text.Encoding]::UTF8
    )

    # 別ファイルへ出力し、標準出力・標準エラーのパイプ詰まりを回避する。
    $prefix = Join-Path ([System.IO.Path]::GetTempPath()) ('tailscale-ssid-' + [Guid]::NewGuid().ToString('N'))
    $stdoutPath = $prefix + '.out'
    $stderrPath = $prefix + '.err'
    $process = $null

    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -ErrorAction Stop

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try {
                $process.Kill()
                [void]$process.WaitForExit(2000)
            }
            catch {
                Write-Log "$Label のタイムアウト後、プロセス終了に失敗: $_" 'WARN'
            }
            throw "$Label が $TimeoutSeconds 秒以内に終了しなかったのじゃ。処理を中断する。"
        }

        $process.Refresh()
        $stdout = ''
        $stderr = ''
        if (Test-Path -LiteralPath $stdoutPath) {
            $stdout = [System.IO.File]::ReadAllText($stdoutPath, $OutputEncoding)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $stderr = [System.IO.File]::ReadAllText($stderrPath, $OutputEncoding)
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Read-TailscaleStatus {
    param ([string]$TailscaleExe)

    Write-Log 'Tailscale の状態を取得するのじゃ。'
    $result = Invoke-ExternalCommand -FilePath $TailscaleExe -Arguments @('status', '--json') -Label 'tailscale status --json' -TimeoutSeconds 15
    if ($result.ExitCode -ne 0) {
        throw "Tailscale の状態取得に失敗したのじゃ (終了コード: $($result.ExitCode))。$($result.StdErr) $($result.StdOut)"
    }
    try {
        return ConvertFrom-Json -InputObject $result.StdOut -ErrorAction Stop
    }
    catch {
        throw "Tailscale の状態 JSON を解析できなかったのじゃ: $_"
    }
}

function Test-ExitNodeMatches {
    param (
        [object]$Status,
        [string]$DesiredIP
    )

    if ([string]::IsNullOrEmpty($DesiredIP)) {
        return ($null -eq $Status.ExitNodeStatus)
    }
    if ($null -eq $Status.ExitNodeStatus) {
        return $false
    }
    $activeIPs = @($Status.ExitNodeStatus.TailscaleIPs | ForEach-Object {
        ([string]$_).Split('/')[0]
    })
    return ($activeIPs -contains $DesiredIP)
}
#endregion

#region Main
try {
    Write-Log 'SSID による Exit Node 設定を開始したのじゃ。'
    Write-Log "ログ: $logFile"

    # -File では複数要素が文字列 1 個として渡ることがある。
    $normalizedSSIDs = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $TargetSSIDs) {
        foreach ($part in ([string]$entry -split ',')) {
            $ssid = $part.Trim().Trim([char]34, [char]39).Trim()
            if (-not [string]::IsNullOrWhiteSpace($ssid) -and $normalizedSSIDs -notcontains $ssid) {
                $normalizedSSIDs.Add($ssid)
            }
        }
    }
    if ($normalizedSSIDs.Count -eq 0) {
        throw '有効な対象 SSID が指定されていないのじゃ。'
    }
    Write-Log "監視対象 SSID: $($normalizedSSIDs -join ', ')"

    #region Tailscale CLI
    $tailscaleCommand = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($null -ne $tailscaleCommand) {
        $tailscaleExe = $tailscaleCommand.Source
    }
    elseif (Test-Path "$env:ProgramFiles\Tailscale\tailscale.exe") {
        $tailscaleExe = "$env:ProgramFiles\Tailscale\tailscale.exe"
    }
    elseif (Test-Path "$env:LOCALAPPDATA\Tailscale\tailscale.exe") {
        $tailscaleExe = "$env:LOCALAPPDATA\Tailscale\tailscale.exe"
    }
    else {
        throw 'tailscale.exe が見つからないのじゃ。インストール先と PATH を確認してくれ。'
    }

    $initialStatus = Read-TailscaleStatus -TailscaleExe $tailscaleExe
    if ($initialStatus.BackendState -ne 'Running') {
        throw "Tailscale が接続状態ではないのじゃ (BackendState: $($initialStatus.BackendState))。"
    }
    #endregion

    #region Wi-Fi SSID Detection
    Write-Log '接続中の Wi-Fi SSID を取得するのじゃ。'
    $wlan = Invoke-ExternalCommand -FilePath 'netsh.exe' -Arguments @('wlan', 'show', 'interfaces') -Label 'netsh wlan show interfaces' -TimeoutSeconds 10 -OutputEncoding ([System.Text.Encoding]::GetEncoding(932))
    $wlanText = $wlan.StdOut + [Environment]::NewLine + $wlan.StdErr
    $noWirelessInterface = $wlanText -match '(?i)there is no wireless interface|ワイヤレス インターフェイスがありません|ワイヤレス インターフェイスはありません'
    $accessDenied = $wlanText -match '(?i)access is denied|アクセスが拒否|位置情報|location'
    if ($accessDenied -or (($wlan.ExitCode -ne 0) -and (-not $noWirelessInterface)) -or [string]::IsNullOrWhiteSpace($wlanText)) {
        throw "Wi-Fi 情報を取得できなかったのじゃ。Exit Node は変更しておらぬ。netsh 出力: $wlanText"
    }

    $connectedSSIDs = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($wlan.StdOut -split '\r?\n')) {
        if ($line -match '^\s*SSID\s*:\s*(.*?)\s*$') {
            $ssid = $Matches[1]
            if (-not [string]::IsNullOrWhiteSpace($ssid) -and $connectedSSIDs -notcontains $ssid) {
                $connectedSSIDs.Add($ssid)
            }
        }
    }

    if ($connectedSSIDs.Count -eq 0) {
        Write-Log '現在接続中の Wi-Fi SSID: なし'
    }
    else {
        Write-Log "現在接続中の Wi-Fi SSID: $($connectedSSIDs -join ', ')"
    }
    #endregion

    #region Set Exit Node
    $matchFound = $false
    foreach ($net in $connectedSSIDs) {
        if ($normalizedSSIDs -contains $net) {
            $matchFound = $true
            break
        }
    }

    if ($matchFound) {
        $desiredExitNode = $ExitNodeIP
        Write-Log "[一致] SSID '$net' を検出したので Exit Node ($ExitNodeIP) を有効化するのじゃ。"
    }
    else {
        $desiredExitNode = ''
        Write-Log '[不一致] 対象 SSID に接続していないので Exit Node を無効化するのじゃ。'
    }

    # 希望する状態なら再設定せず終了。CLI のハングも減らせる。
    if (Test-ExitNodeMatches -Status $initialStatus -DesiredIP $desiredExitNode) {
        Write-Log '[成功] Exit Node は既に希望する状態じゃ。変更は不要。'
        exit 0
    }

    Write-Log 'tailscale set を実行するのじゃ (制限時間: 20 秒)。'
    $setResult = Invoke-ExternalCommand -FilePath $tailscaleExe -Arguments @('set', "--exit-node=$desiredExitNode") -Label 'tailscale set' -TimeoutSeconds 20
    if ($setResult.ExitCode -ne 0) {
        throw "Exit Node の設定に失敗したのじゃ (終了コード: $($setResult.ExitCode))。$($setResult.StdErr) $($setResult.StdOut)"
    }
    Write-Log 'tailscale set コマンドが正常終了したのじゃ。'
    #endregion

    #region Verify
    $verified = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        if ($attempt -gt 1) {
            Start-Sleep -Milliseconds 700
        }
        $verifyStatus = Read-TailscaleStatus -TailscaleExe $tailscaleExe
        if (Test-ExitNodeMatches -Status $verifyStatus -DesiredIP $desiredExitNode) {
            $verified = $true
            break
        }
        Write-Log "Exit Node の状態反映を待っておる ($attempt / 3)。" 'WARN'
    }
    if (-not $verified) {
        throw 'Tailscale は設定を受け付けたが、状態確認で希望する Exit Node を確認できなかったのじゃ。'
    }
    if ($matchFound) {
        Write-Log "[成功] Exit Node $ExitNodeIP が設定されておる。(Online: $($verifyStatus.ExitNodeStatus.Online))"
    }
    else {
        Write-Log '[成功] Exit Node が無効になっていることを確認したのじゃ。'
    }
    #endregion

    Write-Log '処理終了。タスクスケジューラへ終了コード 0 を返すのじゃ。'
    exit 0
}
catch {
    Write-Log "処理失敗: $($_.Exception.Message)" 'ERROR'
    exit 1
}
#endregion

<#
.SYNOPSIS
    接続中の Wi-Fi SSID に応じて Tailscale の Exit Node を切り替えるのじゃ。
.DESCRIPTION
    netsh wlan show interfaces で接続中の実 SSID を取得する。
    TargetSSIDs に一致すれば ExitNodeIP を設定し、一致しなければ解除する。

    通常の PowerShell からの配列指定と、タスクスケジューラの
    powershell.exe -File から渡されたカンマ区切り文字列の両方に対応。
    SSID 自体にカンマが含まれる場合は対応しない。

    Tailscale を含む外部コマンドに実行時間制限を設け、停止時は
    終了コード 1 を返す。成功時は終了コード 0 を返す。
    希望する状態なら再設定を省略する。
    実行ログは ProgramData 以下に保存する。

    スクリプトは実行時に一度だけ判定し、常駐監視はしないのじゃ。
.PARAMETER TargetSSIDs
    Exit Node を有効化する Wi-Fi SSID。
    PowerShell からは "SSID1","SSID2"、タスクスケジューラでは
    -TargetSSIDs "SSID1,SSID2" と渡すのじゃ。
.PARAMETER ExitNodeIP
    使用する Exit Node の Tailscale IP アドレス。
.PARAMETER h
    詳細ヘルプを表示する。
.PARAMETER help
    詳細ヘルプを表示する。
.EXAMPLE
    .\Set-TailscaleExitNode.ps1 -TargetSSIDs "Saizeriya_Free","tech-freewifi" -ExitNodeIP "100.113.112.21"
.EXAMPLE
    .\Set-TailscaleExitNode.ps1 -TargetSSIDs "Saizeriya_Free,tech-freewifi" -ExitNodeIP "100.113.112.21"
.EXAMPLE
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\Set-TailscaleExitNode.ps1" -TargetSSIDs "Saizeriya_Free,tech-freewifi" -ExitNodeIP "100.113.112.21"
.EXAMPLE
    .\Set-TailscaleExitNode.ps1 -h
.NOTES
    Windows PowerShell 5.1 以降と Tailscale CLI が必要じゃ。
    タスクスケジューラでは powershell.exe を直接指定し、
    -NoExit や cmd.exe /k は付けないこと。
    ログ: %ProgramData%\Windows-homebrew-scripts\Logs\Set-TailscaleExitNode.log
    ログの書き込みが拒否された場合は TEMP に保存する。
    Windows 11 の設定によっては位置情報の許可が必要じゃ。
    Wi-Fi 情報取得が失敗した場合は Exit Node を変更しない。
#>
