<#
下にヘルプが書いてあるから、ちゃんと読むのじゃ。
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
if ($h -or $help -or $null -eq $TargetSSIDs -or $TargetSSIDs.Count -eq 0 -or [string]::IsNullOrEmpty($ExitNodeIP)) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit
}
#endregion

#region Main Logic
$currentNetworks = Get-NetConnectionProfile | Select-Object -ExpandProperty Name
$matchFound = $false

foreach ($net in $currentNetworks) {
    if ($TargetSSIDs -contains $net) {
        $matchFound = $true
        break
    }
}

if ($matchFound) {
    tailscale set --exit-node=$ExitNodeIP
}
else {
    tailscale set --exit-node=""
}
#endregion

<#
.SYNOPSIS
    TailscaleのExitノードをSSIDに応じて自動で切り替えるスクリプトじゃ。複数SSIDに対応しておるぞ。
.DESCRIPTION
    現在のネットワークプロファイル（SSID）を取得し、指定されたSSIDリストのいずれかと一致する場合は
    Exitノードを有効にし、一致しない場合はExitノードの利用を解除するのじゃ。
.PARAMETER TargetSSIDs
    接続時にExitノードを利用したい対象のSSIDじゃ。カンマ区切りで複数指定できるぞ。
.PARAMETER ExitNodeIP
    利用するExitノードのTailscale IPアドレスじゃ。
.PARAMETER h
    ヘルプを表示するオプションじゃ。
.PARAMETER help
    ヘルプを表示するオプションじゃ。
.EXAMPLE
    .\Set-TailscaleExitNode.ps1 -TargetSSIDs "SSID1","SSID2" -ExitNodeIP "100.x.y.z"
#>