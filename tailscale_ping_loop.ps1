#regionヘルプ
<#
.SYNOPSIS
    指定したTailscaleデバイスに継続的にpingを送信します。

.DESCRIPTION
    TailscaleデバイスのIPアドレスを入力すると、そのデバイスに対して1秒ごとにpingを送信し続けます。
    pingの結果に応じて色分け表示されます。
    - direct connection not established: 赤
    - DERP: 黄
    - IPアドレス: 緑
    - timeout: 濃い黄

.PARAMETER help
    このヘルプを表示します。

.EXAMPLE
    .\tailscale_ping_loop.ps1
    実行すると、Tailscaleデバイス一覧が表示され、pingを送信するデバイスのIPアドレスを尋ねられます。
#>
#endregion

param(
    [Parameter(Mandatory=$false, HelpMessage="ヘルプを表示します。")]
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# Tailscale Pingループスクリプト (UTF-8で保存)

# --- 管理者権限のチェックと昇格 ---
# 今のユーザーが管理者かどうか確認するのじゃ
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "管理者権限で実行されておらん！自動で昇格するぞ。" -ForegroundColor Yellow
    # 自分自身を管理者として再起動するのじゃ
    Start-Process powershell.exe -ArgumentList "-File", "`"$PSCommandPath`"" -Verb RunAs
    exit # 昇格が完了したら、今のスクリプトは役目を終えるのじゃ
}
# ここから下が、元のスクリプトじゃ
Write-Host "管理者として実行されたぞ。よしよし。" -ForegroundColor Green
Write-Host ""


# --- Tailscaleデバイス一覧の表示 ---
Write-Host "========================================" -ForegroundColor Green
Write-Host " Tailscaleデバイス一覧じゃ" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
# 'tailscale status'の出力を1行ずつ処理して、見やすく整形するのじゃ
tailscale status | ForEach-Object {
    $line = $_ -split '\s+' # 空白文字で分割する
    if ($line.Count -ge 2) {
        "{0}`t{1}" -f $line[0], $line[1] # 1番目と2番目の要素をタブ区切りで表示
    }
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# --- ユーザーからのIPアドレス入力 ---
$target_ip = Read-Host -Prompt "Pingを送るデバイスのIPアドレスを入力せい"

# --- 入力値のチェック ---
if ([string]::IsNullOrWhiteSpace($target_ip)) {
    Write-Host "IPアドレスが入力されておらんではないか。やり直せ！" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "[$target_ip] に1秒おきにpingを送信するぞ。" -ForegroundColor Cyan
Write-Host "止めたければ Ctrl+C を押すがよい。" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

# --- Pingループ (色分け機能付き) ---
# Ctrl+C で中断されるまで、永遠にpingを送り続けるのじゃ
while ($true) {
    # 時刻を取得して表示するのじゃ
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp]"

    # tailscale pingを実行し、その出力を1行ずつ色分け処理するのじゃ
    tailscale ping $target_ip | ForEach-Object {
        $line = $_.Trim()
        
        # direct connection not establishedの場合は赤色じゃ
        if ($line -like "*direct connection not established*") {
            Write-Host $line -ForegroundColor Red
        }
        # DERPの場合は黄色じゃ
        elseif ($line -like "*DERP(*") {
            Write-Host $line -ForegroundColor Yellow
        }
        # IPアドレス(v4 or v6)が含まれておったら黄緑色じゃ
        elseif ($line -match "\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b|\[[0-9a-fA-F:]+\]") {
            Write-Host $line -ForegroundColor Green
        }
        # timeout の場合は濃い黄色(DarkYellow)にするかの
        elseif ($line -like "*timeout*") {
            Write-Host $line -ForegroundColor DarkYellow
        }
        # それ以外はそのまま表示してやる
        else {
            Write-Host $line
        }
    }
    
    Start-Sleep -Seconds 1 # 1秒待機
}
