#region HELP
<#
.SYNOPSIS
    Tailscale の接続状態を JSON ベースで定期表示するのじゃ。

.DESCRIPTION
    `tailscale status --json` の機械可読なステータスを取得し、
    Tailscale ネットワークの状態を端末上で見やすく表示するのじゃ。

    従来版のように `tailscale status` のテキスト出力を正規表現で分解せず、
    JSON の構造をそのまま利用するため、ホスト名・OS・接続経路・通信量・
    サブネットルート・最終確認時刻などを安定して扱えるのじゃ。

    標準表示では以下を重点的に表示するぞ。
      - ローカルノードの Tailscale IPv4 / IPv6
      - Online / Active / Direct / DERP / Peer Relay / SubnetRoutes / ExitCandidates の集計
      - Peer ごとの Online / Active / 接続経路
      - Peer ごとの Tailscale IPv4 アドレス
      - Peer ごとのグローバル IPv6 エンドポイント検出状況
      - RX / TX 通信量
      - ネットワークマップ / MagicSock / WireGuard Engine の不整合

    G6 はローカルノードの `tailscale netcheck --format=json` の GlobalV6 を使って
    判定するのじゃ。現在の P2P 通信経路が IPv6 かどうかではないぞ。

.PARAMETER Interval
    ステータスを取得・表示する周期を秒単位で指定するのじゃ。
    デフォルトは1秒じゃ。

.PARAMETER OnlineOnly
    Offline の Peer を一覧から隠すのじゃ。

.PARAMETER Detail
    詳細表示を有効にするのじゃ。
    DNS 名、実際の接続先、LastHandshake、LastSeen などを追加表示するぞ。

.PARAMETER Help
    このヘルプメッセージを表示するのじゃ。

.EXAMPLE
    PS > .\Tailscale_Status-Loop.ps1

.EXAMPLE
    PS > .\Tailscale_Status-Loop.ps1 -Interval 5 -OnlineOnly

.EXAMPLE
    PS > .\Tailscale_Status-Loop.ps1 -Detail

.NOTES
    スクリプトを止めるには Ctrl+C を押すがよい。
    Tailscale CLI の JSON 形式は将来変更される可能性があるため、
    存在しない任意フィールドは安全に既定値へフォールバックする設計じゃ。
#>
#endregion

param(
    [Parameter(HelpMessage = "取得・表示周期を秒単位で指定します（デフォルト: 1）")]
    [ValidateRange(1, 3600)]
    [int]$Interval = 1,

    [Parameter(HelpMessage = "Offline の Peer を一覧から隠します")]
    [switch]$OnlineOnly,

    [Parameter(HelpMessage = "DNS名・接続先・LastHandshake 等の詳細情報を表示します")]
    [switch]$Detail,

    [Parameter(HelpMessage = "ヘルプを表示します")]
    [Alias('h')]
    [switch]$Help
)

#region INITIALIZE
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

$ErrorActionPreference = 'Stop'
$script:PreviousFrameLineCount = 0
#endregion

#region FORMAT
function Format-Bytes {
    param(
        [AllowNull()]
        [object]$Bytes
    )

    if ($null -eq $Bytes) {
        return '-'
    }

    try {
        [double]$value = $Bytes
    }
    catch {
        return '-'
    }

    if ($value -ge 1TB) {
        return '{0:N2} TB' -f ($value / 1TB)
    }

    if ($value -ge 1GB) {
        return '{0:N2} GB' -f ($value / 1GB)
    }

    if ($value -ge 1MB) {
        return '{0:N2} MB' -f ($value / 1MB)
    }

    if ($value -ge 1KB) {
        return '{0:N2} KB' -f ($value / 1KB)
    }

    return '{0:N0} B' -f $value
}

function Format-ShortDateTime {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return '-'
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return '-'
    }

    try {
        $timestamp = [DateTimeOffset]::Parse($text)

        if ($timestamp.Year -le 1) {
            return '-'
        }

        return $timestamp.ToLocalTime().ToString('MM-dd HH:mm:ss')
    }
    catch {
        return $text
    }
}

function Format-DaysUntil {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return '-'
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return '-'
    }

    try {
        $timestamp = [DateTimeOffset]::Parse($text)
        if ($timestamp.Year -le 1) {
            return '-'
        }

        $days = [math]::Ceiling(($timestamp.ToLocalTime() - [DateTimeOffset]::Now).TotalDays)
        return '{0}日' -f $days
    }
    catch {
        return '-'
    }
}

function Get-StringArray {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @($Value | ForEach-Object {
        if ($null -ne $_) {
            [string]$_
        }
    })
}

function Get-IPv4Address {
    param(
        [AllowNull()]
        [object]$Value
    )

    foreach ($address in (Get-StringArray $Value)) {
        if ($address -notmatch ':') {
            return $address
        }
    }

    return '-'
}

function Get-IPv6Address {
    param(
        [AllowNull()]
        [object]$Value
    )

    foreach ($address in (Get-StringArray $Value)) {
        if ($address -match ':') {
            return $address
        }
    }

    return '-'
}

function Join-Values {
    param(
        [AllowNull()]
        [object]$Value,

        [string]$Separator = ', '
    )

    $values = Get-StringArray $Value

    if ($values.Count -eq 0) {
        return '-'
    }

    return ($values -join $Separator)
}

function Limit-Text {
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    if ($Width -le 0) {
        return ''
    }

    if ($null -eq $Text) {
        $Text = ''
    }

    if ($Text.Length -le $Width) {
        return $Text
    }

    if ($Width -le 1) {
        return $Text.Substring(0, $Width)
    }

    return ($Text.Substring(0, $Width - 1) + '…')
}

function Format-Cell {
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    return (Limit-Text -Text $Text -Width $Width).PadRight($Width)
}
#endregion

#region TAILSCALE
function Get-TailscaleJson {
    $raw = & tailscale status --json 2>&1

    if ($LASTEXITCODE -ne 0) {
        $message = ($raw | Out-String).Trim()

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "tailscale status --json が終了コード $LASTEXITCODE で失敗したのじゃ。"
        }

        throw $message
    }

    if ($null -eq $raw) {
        throw 'tailscale status --json が何も返さなかったのじゃ。'
    }

    $jsonText = ($raw | Out-String).Trim()

    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw 'tailscale status --json が空の JSON を返したのじゃ。'
    }

    try {
        return ($jsonText | ConvertFrom-Json)
    }
    catch {
        throw "Tailscale の JSON を解析できなかったのじゃ: $($_.Exception.Message)"
    }
}

function Get-PeerObjects {
    param(
        [Parameter(Mandatory)]
        [object]$Status
    )

    if ($null -eq $Status.Peer) {
        return @()
    }

    $properties = $Status.Peer.PSObject.Properties

    return @(
        foreach ($property in $properties) {
            if ($null -ne $property.Value) {
                $property.Value
            }
        }
    )
}

function Get-PathType {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    if (-not $Peer.Online) {
        return 'OFFLINE'
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Peer.CurAddr)) {
        return 'DIRECT'
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Peer.PeerRelay)) {
        return 'PEER'
    }

    if ($Peer.Active -and -not [string]::IsNullOrWhiteSpace([string]$Peer.Relay)) {
        return 'DERP'
    }

    return 'IDLE'
}

function Get-PathDisplay {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    switch (Get-PathType -Peer $Peer) {
        'DIRECT' { return 'DIRECT' }
        'PEER' { return 'PEER-RELAY' }
        'DERP' {
            $relay = [string]$Peer.Relay
            if ([string]::IsNullOrWhiteSpace($relay)) {
                return 'DERP'
            }
            return "DERP($relay)"
        }
        'OFFLINE' { return 'OFFLINE' }
        'IDLE' { return 'IDLE' }
        default { return '-' }
    }
}

function Get-CommunicationAddress {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$Peer.CurAddr)) {
        return [string]$Peer.CurAddr
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Peer.PeerRelay)) {
        return [string]$Peer.PeerRelay
    }

    if ($Peer.Active -and -not [string]::IsNullOrWhiteSpace([string]$Peer.Relay)) {
        return "DERP:$([string]$Peer.Relay)"
    }

    return '-'
}

function Get-DiagnosticFlags {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    $flags = [System.Collections.Generic.List[string]]::new()

    if ($Peer.Online -and $Peer.Active) {
        if (-not $Peer.InNetworkMap) {
            [void]$flags.Add('!MAP')
        }

        if (-not $Peer.InMagicSock) {
            [void]$flags.Add('!MAGIC')
        }

        if (-not $Peer.InEngine) {
            [void]$flags.Add('!ENGINE')
        }
    }

    if ($Peer.Expired) {
        [void]$flags.Add('EXPIRED')
    }

    return ($flags -join ' ')
}

function Get-NetcheckJson {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName = 'tailscale.exe'
    $process.StartInfo.Arguments = 'netcheck --format=json'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true

    try {
        if (-not $process.Start()) {
            throw 'tailscale netcheck --format=json を起動できなかったのじゃ。'
        }

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    if ($exitCode -ne 0) {
        $message = $stderr.Trim()

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "tailscale netcheck --format=json が終了コード $exitCode で失敗したのじゃ。"
        }

        throw $message
    }

    $jsonText = $stdout.Trim()

    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw 'tailscale netcheck --format=json が空の JSON を返したのじゃ。'
    }

    try {
        return ($jsonText | ConvertFrom-Json)
    }
    catch {
        throw "Tailscale netcheck の JSON を解析できなかったのじゃ: $($_.Exception.Message)"
    }
}

function Get-LocalIPv6Status {
    param(
        [AllowNull()]
        [object]$Netcheck
    )

    if ($null -eq $Netcheck) {
        return 'G6 ?'
    }

    $globalV6 = [string]$Netcheck.GlobalV6

    if (-not [string]::IsNullOrWhiteSpace($globalV6) -and
        $globalV6 -notmatch 'invalid IP:port|0\.0\.0\.0:0|\[?::\]?:0') {
        return "G6 YES $globalV6"
    }

    if ([bool]$Netcheck.IPv6) {
        return 'G6 NO-ADDR'
    }

    return 'G6 NO'
}

function Test-GlobalIPv6Address {
    param(
        [AllowNull()]
        [string]$Address
    )

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return $false
    }

    try {
        $parsed = [System.Net.IPAddress]::Parse($Address)

        if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            return $false
        }

        $bytes = $parsed.GetAddressBytes()
        return (($bytes[0] -band 0xE0) -eq 0x20)
    }
    catch {
        return $false
    }
}

function Test-GlobalIPv6Endpoint {
    param(
        [AllowNull()]
        [object]$Value
    )

    foreach ($endpoint in (Get-StringArray $Value)) {
        $address = $null

        if ($endpoint -match '^\[(?<address>[0-9A-Fa-f:]+)\](?::\d+)?$') {
            $address = $Matches['address']
        }
        elseif ($endpoint -match '^(?<address>[0-9A-Fa-f:]+)$') {
            $address = $Matches['address']
        }

        if (Test-GlobalIPv6Address -Address $address) {
            return $true
        }
    }

    return $false
}

function Get-GlobalIPv6Status {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    if (Test-GlobalIPv6Endpoint -Value $Peer.Addrs) {
        return 'YES'
    }

    if (Test-GlobalIPv6Endpoint -Value $Peer.CurAddr) {
        return 'YES'
    }

    return '-'
}

function Get-PeerDisplayName {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    $dnsName = [string]$Peer.DNSName

    if (-not [string]::IsNullOrWhiteSpace($dnsName)) {
        $dnsName = $dnsName.TrimEnd('.')
        $machineName = $dnsName.Split('.')[0]

        if (-not [string]::IsNullOrWhiteSpace($machineName)) {
            return $machineName
        }
    }

    return '(unknown)'
}

function Get-PeerSortOrder {
    param(
        [Parameter(Mandatory)]
        [object]$Peer
    )

    if ($Peer.Online -and $Peer.Active) {
        return 0
    }

    if ($Peer.Online) {
        return 1
    }

    return 2
}

function Resolve-UserDisplayName {
    param(
        [Parameter(Mandatory)]
        [object]$Status,

        [AllowNull()]
        [object]$UserId
    )

    if ($null -eq $Status.User -or $null -eq $UserId) {
        return '-'
    }

    $key = [string]$UserId
    $property = $Status.User.PSObject.Properties[$key]

    if ($null -eq $property -or $null -eq $property.Value) {
        return '-'
    }

    $profile = $property.Value
    $displayName = [string]$profile.DisplayName

    if (-not [string]::IsNullOrWhiteSpace($displayName)) {
        return $displayName
    }

    $loginName = [string]$profile.LoginName
    if (-not [string]::IsNullOrWhiteSpace($loginName)) {
        return $loginName
    }

    return '-'
}
#endregion

#region RENDER
function Get-WindowWidth {
    try {
        return [math]::Max(60, $Host.UI.RawUI.WindowSize.Width - 1)
    }
    catch {
        return 119
    }
}

function Write-Frame {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Frame
    )

    $width = Get-WindowWidth
    $frameArray = @($Frame)

    try {
        $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    }
    catch {
        Clear-Host
    }

    $currentLine = 0

    foreach ($entry in $frameArray) {
        $text = Limit-Text -Text ([string]$entry.Text) -Width $width
        $padded = $text.PadRight($width)

        if ($entry.PSObject.Properties['Color']) {
            Write-Host $padded -ForegroundColor $entry.Color
        }
        else {
            Write-Host $padded
        }

        $currentLine++
    }

    while ($currentLine -lt $script:PreviousFrameLineCount) {
        Write-Host (' ' * $width)
        $currentLine++
    }

    $script:PreviousFrameLineCount = $frameArray.Count
}

function New-Frame {
    param(
        [Parameter(Mandatory)]
        [object]$Status
    )

    $width = Get-WindowWidth
    $frame = [System.Collections.Generic.List[object]]::new()

    $now = Get-Date
    $self = $Status.Self
    $peers = @(Get-PeerObjects -Status $Status)

    if ($OnlineOnly) {
        $displayPeers = @($peers | Where-Object { $_.Online })
    }
    else {
        $displayPeers = @($peers)
    }

    $displayPeers = @(
        $displayPeers |
            ForEach-Object {
                [pscustomobject]@{
                    Peer = $_
                    SortOrder = Get-PeerSortOrder -Peer $_
                    Name = Get-PeerDisplayName -Peer $_
                }
            } |
            Sort-Object SortOrder, Name |
            ForEach-Object { $_.Peer }
    )

    $onlinePeers = @($peers | Where-Object { $_.Online })
    $activePeers = @($peers | Where-Object { $_.Active })
    $directPeers = @($onlinePeers | Where-Object { (Get-PathType -Peer $_) -eq 'DIRECT' })
    $peerRelayPeers = @($onlinePeers | Where-Object { (Get-PathType -Peer $_) -eq 'PEER' })
    $relayPeers = @($onlinePeers | Where-Object { (Get-PathType -Peer $_) -eq 'DERP' })
    $idlePeers = @($onlinePeers | Where-Object { (Get-PathType -Peer $_) -eq 'IDLE' })
    $routePeers = @($onlinePeers | Where-Object { @(Get-StringArray $_.PrimaryRoutes).Count -gt 0 })
    $exitPeers = @($onlinePeers | Where-Object { $_.ExitNodeOption })
    $selfName = Get-PeerDisplayName -Peer $self
    $selfIPv4 = Get-IPv4Address -Value $self.TailscaleIPs
    $selfIPv6 = Get-IPv6Address -Value $self.TailscaleIPs

$netcheck = Get-NetcheckJson
    $localIPv6Status = Get-LocalIPv6Status -Netcheck $netcheck

    $title = "[{0}] Tailscale Status :: {1}" -f $now.ToString('yyyy-MM-dd HH:mm:ss'), $selfName
    $line1 = "Local {0} | IPv4 {1} | IPv6 {2}" -f `
        $selfName, $selfIPv4, $selfIPv6

    $line2 = "Peers {0}/{1} online | {2} active | Direct {3} | DERP {4} | PeerRelay {5} | Idle {6} | SubnetRoutes {7} | ExitCandidates {8}" -f `
        $onlinePeers.Count,
        $peers.Count,
        $activePeers.Count,
        $directPeers.Count,
        $relayPeers.Count,
        $peerRelayPeers.Count,
        $idlePeers.Count,
        $routePeers.Count,
        $exitPeers.Count

    [void]$frame.Add([pscustomobject]@{ Text = $title; Color = 'Green' })
    [void]$frame.Add([pscustomobject]@{ Text = $line1; Color = 'Cyan' })
    [void]$frame.Add([pscustomobject]@{ Text = $line2; Color = 'Cyan' })

    [void]$frame.Add([pscustomobject]@{
        Text = ('-' * [math]::Min($width, 140))
        Color = 'DarkCyan'
    })

    $columns = @(
        @{ Name = 'ST';     Width = 6 }
        @{ Name = 'PATH';   Width = 11 }
        @{ Name = 'ADDR';   Width = 22 }
        @{ Name = 'HOST';   Width = 22 }
        @{ Name = 'OS';     Width = 7 }
        @{ Name = 'IP';     Width = 15 }
        @{ Name = 'G6';     Width = 4 }
        @{ Name = 'RX';     Width = 10 }
        @{ Name = 'TX';     Width = 10 }

        @{ Name = 'DIAG';   Width = 12 }
    )

    if ($Detail) {
        $columns = @(
            @{ Name = 'ST';     Width = 6 }
            @{ Name = 'PATH';   Width = 11 }
            @{ Name = 'ADDR';   Width = 22 }
            @{ Name = 'HOST';   Width = 20 }
            @{ Name = 'OS';     Width = 7 }
            @{ Name = 'IP';     Width = 15 }
            @{ Name = 'G6';     Width = 4 }
            @{ Name = 'LAST';   Width = 16 }
            @{ Name = 'DIAG';   Width = 12 }
        )
    }

    $header = ''
    foreach ($column in $columns) {
        if ($header.Length -gt 0) {
            $header += ' '
        }

        $header += (Format-Cell -Text $column.Name -Width $column.Width)
    }

    [void]$frame.Add([pscustomobject]@{
        Text = $header
        Color = 'White'
    })

    foreach ($peer in $displayPeers) {
        $state = if (-not $peer.Online) {
            'OFFLINE'
        }
        elseif ($peer.Active) {
            'ACTIVE'
        }
        else {
            'ONLINE'
        }

        $path = Get-PathDisplay -Peer $peer
        $address = Get-CommunicationAddress -Peer $peer
        $hostName = Get-PeerDisplayName -Peer $peer
        $os = [string]$peer.OS
        $ip = Get-IPv4Address -Value $peer.TailscaleIPs
        $globalIPv6 = Get-GlobalIPv6Status -Peer $peer
        $rx = Format-Bytes -Bytes $peer.RxBytes
        $tx = Format-Bytes -Bytes $peer.TxBytes
        $diag = Get-DiagnosticFlags -Peer $peer

        if ($Detail) {
            $last = '-'

            if ($peer.Online -and $peer.Active) {
                $last = Format-ShortDateTime -Value $peer.LastHandshake
            }
            elseif (-not $peer.Online) {
                $last = Format-ShortDateTime -Value $peer.LastSeen
            }

            $values = @(
                (Format-Cell -Text $state -Width 6),
                (Format-Cell -Text $path -Width 11),
                (Format-Cell -Text $address -Width 22),
                (Format-Cell -Text $hostName -Width 20),
                (Format-Cell -Text $os -Width 7),
                (Format-Cell -Text $ip -Width 15),
                (Format-Cell -Text $globalIPv6 -Width 4),
                (Format-Cell -Text $last -Width 16),
                (Format-Cell -Text $diag -Width 12)
            )
        }
        else {
            $values = @(
                (Format-Cell -Text $state -Width 6),
                (Format-Cell -Text $path -Width 11),
                (Format-Cell -Text $address -Width 22),
                (Format-Cell -Text $hostName -Width 22),
                (Format-Cell -Text $os -Width 7),
                (Format-Cell -Text $ip -Width 15),
                (Format-Cell -Text $globalIPv6 -Width 4),
                (Format-Cell -Text $rx -Width 10),
                (Format-Cell -Text $tx -Width 10),
                (Format-Cell -Text $diag -Width 12)
            )
        }

        $row = ($values -join ' ')
        $rowColor = 'Gray'

        if ($peer.Online -and $peer.Active) {
            $rowColor = 'Green'
        }
        elseif ($peer.Online) {
            $rowColor = 'White'
        }
        elseif (-not $peer.Online) {
            $rowColor = 'DarkGray'
        }

        if (-not [string]::IsNullOrWhiteSpace($diag)) {
            $rowColor = 'Yellow'
        }

        [void]$frame.Add([pscustomobject]@{
            Text = $row
            Color = $rowColor
        })
    }

    [void]$frame.Add([pscustomobject]@{
        Text = ('-' * [math]::Min($width, 140))
        Color = 'DarkCyan'
    })

    [void]$frame.Add([pscustomobject]@{
        Text = "Local Netcheck | $localIPv6Status"
        Color = 'Cyan'
    })

    return $frame
}
#endregion

#region MAIN
$nextUpdate = [DateTime]::UtcNow

while ($true) {
    try {
        $status = Get-TailscaleJson
        $frame = New-Frame -Status $status
        Write-Frame -Frame $frame
    }
    catch {
        $width = Get-WindowWidth

        try {
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
        }
        catch {
            Clear-Host
        }

        $errorText = Limit-Text -Text ("ERROR: " + $_.Exception.Message) -Width $width
        Write-Host $errorText.PadRight($width) -ForegroundColor Red

        if ($script:PreviousFrameLineCount -gt 1) {
            for ($i = 1; $i -lt $script:PreviousFrameLineCount; $i++) {
                Write-Host (' ' * $width)
            }
        }

        $script:PreviousFrameLineCount = [math]::Max(1, $script:PreviousFrameLineCount)
    }

    $nextUpdate = $nextUpdate.AddSeconds($Interval)
    $remainingMilliseconds = [math]::Round(($nextUpdate - [DateTime]::UtcNow).TotalMilliseconds)

    if ($remainingMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $remainingMilliseconds
    }
    else {
        $nextUpdate = [DateTime]::UtcNow
    }
}
#endregion