#region ヘルプ
<#
.SYNOPSIS
    現在のWi-Fi接続情報を定期的に表示します。

.DESCRIPTION
    netsh wlan show interfaces コマンドの出力を1秒ごとに画面更新して表示し続けます。

.PARAMETER help
    このヘルプを表示します。

.EXAMPLE
    .\WiFi_Get-Info.ps1
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

# Wi-Fi情報を定期的に表示するループ
while ($true) {
    Clear-Host
    netsh wlan show interfaces
    Start-Sleep -Seconds 1
}
