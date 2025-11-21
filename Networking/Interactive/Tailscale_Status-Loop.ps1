#regionヘルプ
<#
.SYNOPSIS
    Tailscaleのステータスを定期的に表示するのじゃ。（残像除去・完全版）

.DESCRIPTION
    このスクリプトは、指定した間隔で 'tailscale status' コマンドを無限に実行し、
    Tailscaleネットワークの状態を監視するために使うのじゃ。
    
    主な機能：
    1. 画面サイズを自動で幅広（135文字）に調整。
    2. メールアドレス列を削除し、各列を固定幅で整列。
    3. 行末に空白パディングを入れることで、文字列が短くなった際の残像（ゴミ）を除去。
    4. ちらつき防止のため、画面クリアではなくカーソル制御を行う。
    
    実行には管理者権限が必要じゃが、なければ自動で昇格を試みるぞ。

.PARAMETER Interval
    ステータスを更新する間隔を秒単位で指定するのじゃ。デフォルトは2秒じゃ。
    指定可能な値は1以上の整数じゃ。

.PARAMETER Help
    このヘルプメッセージを表示するのじゃ。

.EXAMPLE
    PS > .\Tailscale_Status-Loop.ps1
    残像もちらつきもない、美しい監視画面が表示されるはずじゃ。

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

    if ($bufSize.Width -lt $targetWidth) { $bufSize.Width = $targetWidth }
    if ($bufSize.Height -lt 3000) { $bufSize.Height = 3000 }
    $rawUI.BufferSize = $bufSize

    $winSize.Width = $targetWidth
    if ($winSize.Height -lt $targetHeight) { $winSize.Height = $targetHeight }
    $rawUI.WindowSize = $winSize
    
    Write-Host "画面サイズを調整したぞ。ここまでは順調じゃ。" -ForegroundColor Cyan
} catch {
    Write-Host "画面サイズの変更に失敗したようじゃが、続行するぞ。" -ForegroundColor Yellow
}

# --- ループ開始前の案内 ---
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Tailscaleのステータスを $($Interval)秒おきに更新するぞ。" -ForegroundColor Cyan
Write-Host "残像が出ないよう、行末までしっかり掃除しながら表示するから安心せい。" -ForegroundColor Cyan
Write-Host "止めたければ Ctrl+C を押すがよい。" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Start-Sleep -Seconds 2
Clear-Host # 最初に一度だけ画面をきれいにする

# --- statusループ (ちらつき対策・整列・残像除去版) ---
while ($true) {
    # 現在のウィンドウ幅を取得（パディング計算用）
    # 端まで埋めると自動改行されてしまうことがあるため、-1 文字分だけ確保する
    $currentWidth = $Host.UI.RawUI.WindowSize.Width - 1
    
    # カーソルを左上(0,0)に移動
    $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    
    # タイトル行の表示（ここもパディングして残像を消す）
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $headerTitle = "[$timestamp] Tailscale Status (No Email / Clean View)"
    Write-Host $headerTitle.PadRight($currentWidth) -ForegroundColor Green
    
    Write-Host ("=" * 40).PadRight($currentWidth) -ForegroundColor Green
    
    # tailscale statusを実行し、整形・パディングして表示
    tailscale status | ForEach-Object {
        $parts = $_ -split '\s+'
        
        if ($parts.Count -ge 4) {
            $ip = $parts[0]
            $hostName = $parts[1]
            $os = $parts[3] # Email($parts[2])をスキップ
            $status = $parts[4..($parts.Length-1)] -join ' '
            
            # 固定幅フォーマットを作成
            $line = "{0,-16} {1,-25} {2,-8} {3}" -f $ip, $hostName, $os, $status
            
            # 【重要】ウィンドウ幅いっぱいまでスペースで埋める（残像消去）
            # 文字列がウィンドウ幅より長い場合はそのまま、短い場合はパディング
            if ($line.Length -lt $currentWidth) {
                $line = $line.PadRight($currentWidth)
            }
            
            Write-Host $line
        } else {
            # 解析できない行もパディングして表示
            if ($_.Length -lt $currentWidth) {
                Write-Host $_.PadRight($currentWidth)
            } else {
                Write-Host $_
            }
        }
    }
    
    Write-Host ("=" * 40).PadRight($currentWidth) -ForegroundColor Green
    
    # 画面下部の掃除（行数が減った場合のために余白で上書き）
    # 念のため多めに空行を入れる
    for ($i = 0; $i -lt 5; $i++) {
        Write-Host (" " * $currentWidth)
    }
    
    Start-Sleep -Seconds $Interval
}