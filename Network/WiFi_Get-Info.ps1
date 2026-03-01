#regionヘルプ
<#
.SYNOPSIS
    現在のWi-Fi接続情報を定期的に表示します。

.DESCRIPTION
    netshコマンドを使用して、現在接続しているWi-Fiの情報を取得し、1秒ごとに画面を更新して表示し続けます。
    表示される情報は以下の通りです。
    - デバイス名
    - SSID
    - IEEE 802.11規格
    - 周波数帯 (Band)
    - チャンネル
    - 受信速度 (Mbps)
    - 送信速度 (Mbps)
    - 電波強度 (シグナル)

.PARAMETER help
    このヘルプを表示します。

.EXAMPLE
    .\Wi-Fi Information.ps1
    スクリプトを実行すると、Wi-Fi情報の表示が開始されます。
#>
#endregion

param(
    [Parameter(Mandatory = $false, HelpMessage = "ヘルプを表示します。")]
    [switch]$help,
    [Parameter(Mandatory = $false, HelpMessage = "1回だけ情報を表示して終了します。")]
    [switch]$once
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# WiFi情報を取得する関数
function Get-WiFiInfo {
    # netsh の出力は OEM コードページ依存で文字化けしやすいため、
    # UTF-8 (英語) に切り替えてから取得する。
    chcp 65001 >$null
    $raw = netsh wlan show interfaces
    $wifiInfo = $raw -split "`r?`n"

    # パース用変数
    $device = $null; $ssid = $null; $radio = $null
    $band = $null; $channel = $null; $downlink = $null
    $uplink = $null; $signal = $null

    foreach ($line in $wifiInfo) {
        if ($line -match '^[ \t]*(?:Description|説明|Name)[ \t]*:[ \t]*(.+)$') {
            $device = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*SSID[ \t]*:[ \t]*(.+)$') {
            $ssid = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*(?:Radio type|無線の種類)[ \t]*:[ \t]*(.+)$') {
            $radio = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*(?:Band|バンド)[ \t]*:[ \t]*(.+)$') {
            $band = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*Channel[ \t]*:[ \t]*(.+)$') {
            $channel = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*(?:Receive rate \(Mbps\)|受信速度 \(Mbps\))[ \t]*:[ \t]*(.+)$') {
            $downlink = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*(?:Transmit rate \(Mbps\)|送信速度 \(Mbps\))[ \t]*:[ \t]*(.+)$') {
            $uplink = $matches[1].Trim()
        }
        elseif ($line -match '^[ \t]*(?:Signal|シグナル)[ \t]*:[ \t]*(.+)$') {
            $signal = $matches[1].Trim()
        }
    }

    # 出力
    if ($device) { Write-Output "デバイス名        : $device" } else { Write-Output "デバイス情報が見つかりませんでした。" }
    if ($ssid) { Write-Output "SSID             : $ssid" } else { Write-Output "SSID情報が見つかりませんでした。" }
    if ($radio) { Write-Output "無線の種類        : $radio" } else { Write-Output "IEEE802_11情報が見つかりませんでした。" }
    if ($band) { Write-Output "バンド           : $band" } else { Write-Output "バンド情報が見つかりませんでした。" }
    if ($channel) { Write-Output "チャネル         : $channel" } else { Write-Output "チャネル情報が見つかりませんでした。" }
    if ($downlink) { Write-Output "受信速度 (Mbps)  : $downlink" }else { Write-Output "受信速度情報が見つかりませんでした。" }
    if ($uplink) { Write-Output "送信速度 (Mbps)  : $uplink" } else { Write-Output "送信速度情報が見つかりませんでした。" }
    if ($signal) { Write-Output "シグナル         : $signal" } else { Write-Output "シグナル情報が見つかりませんでした。" }
}



# -once オプションが指定された場合は1回だけ情報を表示して終了
if ($once) {
    Get-WiFiInfo
    exit
}

# 定期的にWiFi情報を表示するループ
while ($true) {
    Clear-Host
    Get-WiFiInfo
    Start-Sleep -Seconds 1  # 1秒ごとに更新
}
