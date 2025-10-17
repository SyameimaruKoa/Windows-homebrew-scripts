#regionヘルプ
<#
.SYNOPSIS
    Tailscaleのステータスを定期的に表示するのじゃ。（ちらつき対策版）

.DESCRIPTION
    このスクリプトは、指定した間隔で 'tailscale status' コマンドを無限に実行し、
    Tailscaleネットワークの状態を監視するために使うのじゃ。
    Clear-Hostの代わりにカーソル位置を制御することで、画面のちらつきを抑制しておる。
    実行には管理者権限が必要じゃが、なければ自動で昇格を試みるぞ。

.PARAMETER Interval
    ステータスを更新する間隔を秒単位で指定するのじゃ。デフォルトは2秒じゃ。
    指定可能な値は1以上の整数じゃ。

.PARAMETER Help
    このヘルプメッセージを表示するのじゃ。

.EXAMPLE
    PS > .\tailscale_status_loop_v2.ps1
    デフォルトの2秒間隔でステータスの監視を始めるぞ。

.EXAMPLE
    PS > .\tailscale_status_loop_v2.ps1 -Interval 5
    5秒間隔でステータスの監視を始めるぞ。

.NOTES
    スクリプトを止めるには Ctrl+C を押すがよい。
#>
#endregion
param(
    [Parameter(HelpMessage = "更新間隔を秒単位で指定します（デフォルト: 2）")]
    [ValidateRange(1, 3600)]
    [int]$Interval = 2,

    [Parameter(HelpMessage = "ヘルプを表示します")]
    [Alias('h')]
    [switch]$Help
)

# -Help または -h が指定されたら、ヘルプを表示して終了するのじゃ
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}


# --- 管理者権限のチェックと昇格 ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "管理者権限で実行されておらん！自動で昇格するぞ。" -ForegroundColor Yellow
    $arguments = "-File `"$PSCommandPath`""
    if ($PSBoundParameters.Count -gt 0) {
        $arguments += " " + ($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" })
    }
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}
Write-Host "管理者として実行されたぞ。よしよし。" -ForegroundColor Green
Write-Host ""


# --- ループ開始前の案内 ---
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Tailscaleのステータスを $($Interval)秒おきに更新するぞ。" -ForegroundColor Cyan
Write-Host "止めたければ Ctrl+C を押すがよい。" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Start-Sleep -Seconds 2
Clear-Host # 最初に一度だけ画面をきれいにする


# --- statusループ (ちらつき対策版) ---
while ($true) {
    # カーソルを左上(0,0)に移動させるのじゃ。これがちらつき防止のキモじゃ。
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    
    # 時刻とタイトルを表示するのじゃ
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] Tailscale Status" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    # tailscale statusを実行するのじゃ
    tailscale status
    
    Write-Host "========================================" -ForegroundColor Green
    # 前回の表示より今回の表示が短い場合に備え、数行分の空白で上書きしておく
    Write-Host "                                        "
    Write-Host "                                        "
    
    Start-Sleep -Seconds $Interval # 指定された秒数だけ待機
}