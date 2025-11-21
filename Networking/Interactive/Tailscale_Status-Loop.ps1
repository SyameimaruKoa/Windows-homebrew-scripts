#regionヘルプ
<#
.SYNOPSIS
    Tailscaleのステータスを定期的に表示するのじゃ。（サイズ自動調整・整形版）

.DESCRIPTION
    このスクリプトは、指定した間隔で 'tailscale status' コマンドを無限に実行し、
    Tailscaleネットワークの状態を監視するために使うのじゃ。
    
    主な機能：
    1. 画面サイズを自動で幅広（135文字）に調整して、折り返しを防ぐ。
    2. メールアドレス列を削除し、各列を固定幅で綺麗に整列させる。
    3. ちらつき防止のため、画面クリアではなくカーソル制御を行う。
    
    実行には管理者権限が必要じゃが、なければ自動で昇格を試みるぞ。

.PARAMETER Interval
    ステータスを更新する間隔を秒単位で指定するのじゃ。デフォルトは2秒じゃ。
    指定可能な値は1以上の整数じゃ。

.PARAMETER Help
    このヘルプメッセージを表示するのじゃ。

.EXAMPLE
    PS > .\Tailscale_Status-Loop.ps1
    デフォルトの2秒間隔でステータスの監視を始めるぞ。画面も勝手に広がるぞ。

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

# --- ウィンドウサイズの最適化 ---
try {
    $targetWidth = 135  # ステータスが長くても折り返さない十分な幅
    $targetHeight = 50  # 一覧を一望できる高さ

    $rawUI = $Host.UI.RawUI
    $bufSize = $rawUI.BufferSize
    $winSize = $rawUI.WindowSize

    # バッファサイズがウィンドウサイズより小さいとエラーになるため、先にバッファを広げる
    if ($bufSize.Width -lt $targetWidth) { $bufSize.Width = $targetWidth }
    # バッファの高さは履歴用に十分に確保する（既に十分大きければそのまま）
    if ($bufSize.Height -lt 3000) { $bufSize.Height = 3000 }

    $rawUI.BufferSize = $bufSize

    # ウィンドウサイズを変更
    $winSize.Width = $targetWidth
    if ($winSize.Height -lt $targetHeight) { $winSize.Height = $targetHeight }
    
    $rawUI.WindowSize = $winSize
    Write-Host "画面サイズを広げておいたぞ（幅$targetWidth, 高さ$targetHeight）。これで見切れんはずじゃ。" -ForegroundColor Cyan
}
catch {
    Write-Host "画面サイズの変更に失敗したようじゃが、環境によっては制限があるからの。気にせず進めるぞ。" -ForegroundColor Yellow
}

# --- ループ開始前の案内 ---
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Tailscaleのステータスを $($Interval)秒おきに更新するぞ。" -ForegroundColor Cyan
Write-Host "メールアドレスを隠し、レイアウトを整列させて表示するのじゃ。" -ForegroundColor Cyan
Write-Host "止めたければ Ctrl+C を押すがよい。" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Start-Sleep -Seconds 2
Clear-Host # 最初に一度だけ画面をきれいにする

# --- statusループ (ちらつき対策・整列版) ---
while ($true) {
    # カーソルを左上(0,0)に移動（ちらつき防止）
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    
    # 時刻とタイトルを表示
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] Tailscale Status (No Email / Optimized Layout)" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    # tailscale statusを実行し、出力を整形して表示する
    tailscale status | ForEach-Object {
        # 空白で分割して配列にする
        $parts = $_ -split '\s+'
        
        # 正常な行（要素が4つ以上ある場合）のみ処理する
        # [0]:IP, [1]:Hostname, [2]:Email, [3]:OS, [4...]:Status
        if ($parts.Count -ge 4) {
            $ip = $parts[0]
            $hostName = $parts[1]
            # $parts[2] (Email) はスキップ
            $os = $parts[3]
            # 残りの部分はステータスとして結合
            $status = $parts[4..($parts.Length - 1)] -join ' '
            
            # 固定幅フォーマットで出力（左詰め）
            # IP:16文字, Hostname:25文字, OS:8文字, Status:残り
            "{0,-16} {1,-25} {2,-8} {3}" -f $ip, $hostName, $os, $status
        }
        else {
            # 解析できない行はそのまま出す
            $_
        }
    }
    
    Write-Host "========================================" -ForegroundColor Green
    # 画面クリアの代わりに余白で上書き（幅を広げた分、余白も多めに）
    Write-Host "                                                                                                    "
    Write-Host "                                                                                                    "
    
    Start-Sleep -Seconds $Interval
}