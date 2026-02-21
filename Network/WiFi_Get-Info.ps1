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
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# WiFi情報を取得する関数
function Get-WiFiInfo {
    $wifiInfo = netsh wlan show interfaces
    # 何番目のインターフェイスを使うかを指定(0から)
    $InterfaceIndex = 0
    $ssidPattern = "^\s*SSID\s*:\s*(.+)$"
    $devicePattern = "^\s*説明\s*:\s*(.+)$"
    $IEEE802_11Pattern = "^\s*無線の種類\s*:\s*(.+)$"
    $bandPattern = "^\s*バンド\s*:\s*(.+)$"
    $channelPattern = "^\s*チャネル\s*:\s*(.+)$"
    $downlinkPattern = "^\s*受信速度\ \(Mbps\)\s*:\s*(.+)$"
    $uplinkPattern = "^\s*送信速度\ \(Mbps\)\s*:\s*(.+)$"
    $signalPattern = "^\s*シグナル\s*:\s*(.+)$"

    $matches_device = $wifiInfo -match $devicePattern
    $matches_ssid = $wifiInfo -match $ssidPattern
    $matches_IEEE802_11 = $wifiInfo -match $IEEE802_11Pattern
    $matches_band = $wifiInfo -match $bandPattern
    $matches_channel = $wifiInfo -match $channelPattern
    $matches_downlink = $wifiInfo -match $downlinkPattern
    $matches_uplink = $wifiInfo -match $uplinkPattern
    $matches_signal = $wifiInfo -match $signalPattern

    if ($matches_device) {
        $device = $matches_device[$InterfaceIndex].Trim()
        Write-Output "$device"
    }
    else {
        Write-Output "デバイス情報が見つかりませんでした。"
    }

    if ($matches_ssid) {
        $ssid = $matches_ssid[$InterfaceIndex].Trim()
        Write-Output "$ssid"
    }
    else {
        Write-Output "SSID情報が見つかりませんでした。"
    }

    if ($matches_IEEE802_11) {
        $IEEE802_11 = $matches_IEEE802_11[$InterfaceIndex].Trim()
        Write-Output "$IEEE802_11"
    }
    else {
        Write-Output "IEEE802_11情報が見つかりませんでした。"
    }

    if ($matches_band) {
        $band = $matches_band[$InterfaceIndex].Trim()
        Write-Output "$band"
    }
    else {
        Write-Output "バンド情報が見つかりませんでした。"
    }

    if ($matches_channel) {
        $channel = $matches_channel[$InterfaceIndex].Trim()
        Write-Output "$channel"
    }
    else {
        Write-Output "チャネル情報が見つかりませんでした。"
    }

    if ($matches_downlink) {
        $downlink = $matches_downlink[$InterfaceIndex].Trim()
        Write-Output "$downlink"
    }
    else {
        Write-Output "受信速度情報が見つかりませんでした。"
    }

    if ($matches_uplink) {
        $uplink = $matches_uplink[$InterfaceIndex].Trim()
        Write-Output "$uplink"
    }
    else {
        Write-Output "送信速度情報が見つかりませんでした。"
    }

    if ($matches_signal) {
        $signal = $matches_signal[$InterfaceIndex].Trim()
        Write-Output "$signal"
    }
    else {
        Write-Output "シグナル情報が見つかりませんでした。"
    }
}



# 定期的にWiFi情報を表示するループ
while ($true) {
    Clear-Host
    Get-WiFiInfo
    Start-Sleep -Seconds 1  # 1秒ごとに更新
}