<#
.SYNOPSIS
    UPXを使って実行ファイルを一括圧縮するのじゃ。

.DESCRIPTION
    指定されたファイル、またはフォルダ内の実行ファイル（.exe, .dll）をUPXで圧縮するスクリプトじゃ。
    オリジナルのファイルはバックアップされるから安心せい。
    失敗時には対話的にリトライするか選択できるぞ。
    進捗バーを確実に出すために、関数ラップをやめて直接実行するようにした最終形態じゃ。

.PARAMETER Path
    圧縮したいファイル、またはフォルダのパスじゃ。
    複数指定も可能じゃし、ワイルドカード（*.exe）も使えるぞ。

.PARAMETER Force
    GUARD_CFなどの保護がかかっているファイルも強制的に圧縮する。
    ただし、セキュリティ機能が無効化されたり、起動しなくなるリスクがあるから注意するのじゃ。
#>

[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true, Position=0)]
    [string[]]$Path,

    [Alias("f")]
    [switch]$Force,

    [Alias("h")]
    [switch]$Help
)

#region ヘルプ表示ロジック
if ($Help -or $null -eq $Path -or $Path.Count -eq 0) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    Write-Host "`n確認したらEnterキーを押して閉じてくれ..." -ForegroundColor Gray
    Read-Host
    exit
}
#endregion

# UPXの確認
$upxCmd = "upx"
if (-not (Get-Command "upx" -ErrorAction SilentlyContinue)) {
    if (Test-Path ".\upx.exe") {
        $upxCmd = (Resolve-Path ".\upx.exe").Path
    } else {
        Write-Error "upx.exe が見つからぬぞ。パスを通すか、同じフォルダに置くのじゃ。"
        Write-Host "`n終了するにはEnterキーを押してくれ..."
        Read-Host
        exit 1
    }
}

Write-Host "処理を開始するぞ..." -ForegroundColor Cyan

$script:userDecision = $null

try {
    foreach ($p in $Path) {
        $resolvedPaths = Resolve-Path $p -ErrorAction SilentlyContinue
        if (-not $resolvedPaths) {
            Write-Warning "指定されたパスが見つからぬ： $p"
            continue
        }

        foreach ($rPath in $resolvedPaths) {
            $item = Get-Item -LiteralPath $rPath.Path
            $filesToProcess = @()

            if ($item -is [System.IO.DirectoryInfo]) {
                Write-Host "フォルダをスキャン中: $($item.FullName)" -ForegroundColor Yellow
                $filesToProcess = Get-ChildItem -Path $item.FullName -Recurse -Include "*.exe", "*.dll"
            } else {
                $filesToProcess = @($item)
            }

            foreach ($file in $filesToProcess) {
                Write-Host "圧縮中: $($file.Name)" -NoNewline
                Write-Host "" # 改行してログを見やすくする

                $isForcedRun = $Force
                if ($script:userDecision -eq 'Always') { $isForcedRun = $true }

                # ---------------------------------------------------------
                # 1回目の実行ブロック
                # ---------------------------------------------------------
                # 引数構築
                [string[]]$upxArgs = @("--best", "-k")
                if ($isForcedRun) { $upxArgs += "--force" }
                $upxArgs += $file.FullName

                # コマンド表示
                Write-Host "   [Exec] $upxCmd $upxArgs" -ForegroundColor DarkGray
                
                # ★ここが修正点じゃ！★
                # 変数への代入を行わず、直接実行することで出力をコンソールに流す
                & $upxCmd $upxArgs
                
                # 直後の終了コードを取得
                $exitCode = $LASTEXITCODE

                # ---------------------------------------------------------
                # 失敗時のリカバリー判定
                # ---------------------------------------------------------
                if ($exitCode -ne 0 -and -not $isForcedRun -and $script:userDecision -ne 'Never') {
                    Write-Host "   [!] エラー終了コード($exitCode) を検知した。" -ForegroundColor Yellow
                    
                    # ユーザー問い合わせ
                    $choice = $null
                    if ($null -eq $script:userDecision) {
                        while ($choice -notmatch "^[yans]$") {
                            Write-Host "   強制的に再試行するかの？" -ForegroundColor Cyan
                            Write-Host "     [Y]es    : 今回のみ強制実行 (--force)"
                            Write-Host "     [A]lways : 以降すべて強制実行"
                            Write-Host "     [N]o     : 今回はやめる"
                            Write-Host "     [S]kip   : 以降すべてエラーを無視"
                            $choice = Read-Host "   選択 [y/a/n/s]"
                        }
                    }

                    switch ($choice.ToLower()) {
                        'y' { $isForcedRun = $true }
                        'a' { $script:userDecision = 'Always'; $isForcedRun = $true; Write-Host "   承知した。以降は強制する。" -ForegroundColor Magenta }
                        's' { $script:userDecision = 'Never'; Write-Host "   以降は無視する。" -ForegroundColor Magenta }
                        'n' { }
                    }

                    # ---------------------------------------------------------
                    # 再実行ブロック (強制モード)
                    # ---------------------------------------------------------
                    if ($isForcedRun) {
                         Write-Host "   -> 強制モードで再実行中..."
                         
                         # 引数再構築
                         [string[]]$retryArgs = @("--best", "-k", "--force", $file.FullName)
                         
                         Write-Host "   [Exec] $upxCmd $retryArgs" -ForegroundColor DarkGray
                         
                         # 再度直接実行
                         & $upxCmd $retryArgs
                         $exitCode = $LASTEXITCODE
                    }
                }

                # 結果表示
                if ($exitCode -eq 0) {
                    Write-Host "[成功]" -ForegroundColor Green
                } else {
                    Write-Host "[失敗] (ExitCode: $exitCode)" -ForegroundColor Red
                }
                Write-Host "----------------------------------------" -ForegroundColor Gray
            }
        }
    }
}
finally {
    Write-Host "`nすべて完了じゃ！" -ForegroundColor Cyan
    Write-Host "終了するにはEnterキーを押してくだされ..." -ForegroundColor Gray
    $null = Read-Host
}