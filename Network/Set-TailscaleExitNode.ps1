<#
このファイルの末尾に Get-Help 用の詳しいヘルプがあります。
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
    exit
}
#endregion

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
    Write-Error "tailscale.exe が見つからないのじゃ。Tailscale のインストールと PATH を確認してくれ。"
    exit 1
}

$initialStatusOutput = @(& $tailscaleExe status --json 2>&1)
$statusExitCode = $LASTEXITCODE
if ($statusExitCode -ne 0) {
    Write-Host ($initialStatusOutput -join [Environment]::NewLine)
    Write-Error "Tailscale の状態取得に失敗したのじゃ (終了コード: $statusExitCode)。"
    exit 1
}

try {
    $initialStatus = ($initialStatusOutput -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Error "Tailscale の状態を JSON として解析できないのじゃ: $_"
    exit 1
}

if ($initialStatus.BackendState -ne 'Running') {
    Write-Error "Tailscale は接続状態ではないのじゃ (BackendState: $($initialStatus.BackendState))。ログインと接続を確認してくれ。"
    exit 1
}
#endregion

#region Wi-Fi SSID Detection
# Get-NetConnectionProfile.Name は Wi-Fi の実 SSID と一致するとは限らない。
# netsh wlan show interfaces から現在接続中の SSID のみを取得する。
$wlanOutput = @(& netsh.exe wlan show interfaces 2>&1)
$wlanExitCode = $LASTEXITCODE
$wlanText = $wlanOutput -join [Environment]::NewLine

# Windows 11 では位置情報の設定によって Wi-Fi 情報が拒否されることがある。
# 取得失敗時に誤って Exit Node を無効化しないため、ここで中断する。
$noWirelessInterface = $wlanText -match '(?i)there is no wireless interface|ワイヤレス インターフェイスがありません|ワイヤレス インターフェイスはありません'
$accessDenied = $wlanText -match '(?i)access is denied|アクセスが拒否|位置情報|location'
if ($accessDenied -or (($wlanExitCode -ne 0) -and (-not $noWirelessInterface)) -or [string]::IsNullOrWhiteSpace($wlanText)) {
    Write-Host $wlanText
    Write-Error "接続中の SSID を安全に判定できなかったのじゃ。Windows の「設定 > プライバシーとセキュリティ > 位置情報」も確認してくれ。Exit Node は変更しておらぬ。"
    exit 1
}

$connectedSSIDs = New-Object System.Collections.Generic.List[string]
foreach ($line in $wlanOutput) {
    if ([string]$line -match '^\s*SSID\s*:\s*(.*?)\s*$') {
        $ssid = $Matches[1]
        if (-not [string]::IsNullOrWhiteSpace($ssid) -and $connectedSSIDs -notcontains $ssid) {
            $connectedSSIDs.Add($ssid)
        }
    }
}

Write-Host "監視対象 SSID: $($TargetSSIDs -join ', ')"
if ($connectedSSIDs.Count -eq 0) {
    Write-Host "現在接続中の Wi-Fi SSID: なし"
}
else {
    Write-Host "現在接続中の Wi-Fi SSID: $($connectedSSIDs -join ', ')"
}
#endregion

#region Main Logic
$matchFound = $false

foreach ($net in $connectedSSIDs) {
    if ($TargetSSIDs -contains $net) {
        $matchFound = $true
        break
    }
}

if ($matchFound) {
    Write-Host "[一致] SSID '$net' が対象に含まれるので Exit Node ($ExitNodeIP) を有効化するのじゃ。"
    $desiredExitNode = $ExitNodeIP
}
else {
    Write-Host "[不一致] 対象 SSID に接続していないので Exit Node を無効化するのじゃ。"
    $desiredExitNode = ''
}

# tailscale up ではなく set を使い、指定した Exit Node 設定だけを変更する。
$setOutput = @(& $tailscaleExe set "--exit-node=$desiredExitNode" 2>&1)
$setExitCode = $LASTEXITCODE
if ($setOutput.Count -gt 0) {
    Write-Host ($setOutput -join [Environment]::NewLine)
}

if ($setExitCode -ne 0) {
    Write-Error "Exit Node の設定に失敗したのじゃ (終了コード: $setExitCode)。上の Tailscale のエラーを確認してくれ。"
    exit 1
}
#endregion

#region Verify
$verifyOutput = @(& $tailscaleExe status --json 2>&1)
$verifyExitCode = $LASTEXITCODE
if ($verifyExitCode -ne 0) {
    Write-Warning "設定コマンドは成功したが、変更後の状態を取得できなかったのじゃ: $($verifyOutput -join ' ')"
    exit 1
}

try {
    $verifyStatus = ($verifyOutput -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Error "変更後の Tailscale 状態を解析できなかったのじゃ: $_"
    exit 1
}

$activeExitNode = $verifyStatus.ExitNodeStatus
if ($matchFound) {
    if ($null -eq $activeExitNode) {
        Write-Warning "Tailscale は設定を受け付けたが、使用中の Exit Node を確認できなかったのじゃ。"
        exit 1
    }

    $activeIPs = @($activeExitNode.TailscaleIPs | ForEach-Object { ([string]$_).Split('/')[0] })
    if ($activeIPs -notcontains $ExitNodeIP) {
        Write-Warning "要求した Exit Node ($ExitNodeIP) と現在の Exit Node ($($activeIPs -join ', ')) が一致しないのじゃ。"
        exit 1
    }

    Write-Host "[成功] Exit Node $ExitNodeIP の使用を確認したのじゃ。(Online: $($activeExitNode.Online))"
}
else {
    if ($null -ne $activeExitNode) {
        Write-Warning "無効化を要求したが、Tailscale はまだ Exit Node を使用中と報告しておる。"
        exit 1
    }

    Write-Host "[成功] Exit Node が無効になっていることを確認したのじゃ。"
}
#endregion

<#
.SYNOPSIS
    Tailscale の Exit Node を現在の Wi-Fi SSID に応じて切り替えるのじゃ。
.DESCRIPTION
    netsh wlan show interfaces で現在接続中の実際の SSID を取得し、
    TargetSSIDs のいずれかに一致すれば ExitNodeIP を設定する。
    一致しなければ既存どおり Exit Node を無効化するのじゃ。

    Get-NetConnectionProfile のネットワークプロファイル名は SSID の代用にしない。
    Tailscale の接続状態・SSID 判定・設定結果・変更後の状態を表示する。
    SSID の取得がエラーになった場合は安全のため既存設定を変更しない。
    このスクリプトは実行したときに一度判定するだけで、常駐監視はしないのじゃ。
.PARAMETER TargetSSIDs
    Exit Node を有効にする Wi-Fi の SSID。カンマで複数指定できるのじゃ。
.PARAMETER ExitNodeIP
    使用する Exit Node の Tailscale IP アドレス。
.PARAMETER h
    詳細ヘルプを表示するのじゃ。
.PARAMETER help
    詳細ヘルプを表示するのじゃ。
.EXAMPLE
    .\Set-TailscaleExitNode.ps1 -TargetSSIDs "Saizeriya_Free","tech-freewifi" -ExitNodeIP "100.113.112.21"
.EXAMPLE
    .\Set-TailscaleExitNode.ps1 -h
.NOTES
    Windows PowerShell 5.1 以降と Tailscale CLI が必要じゃ。
    Windows 11 では位置情報を許可しないと SSID を取得できない場合があるのじゃ。
    接続中の SSID を確認できない状態での誤った変更を防ぐため、
    netsh の情報取得自体が失敗したときは変更せずに終了するぞ。
#>
