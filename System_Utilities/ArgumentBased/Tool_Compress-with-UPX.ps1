<#
.SYNOPSIS
    UPXを使って実行ファイルを一括圧縮するのじゃ。

.DESCRIPTION
    指定されたファイル、またはフォルダ内の実行ファイル（.exe, .dll, .so, .dat 等）をUPXで圧縮するスクリプトじゃ。
    起動時に対話モードで動作を選択できるほか、Keep(バックアップ)やForce(強制)の設定もその場で変更可能じゃ。

.PARAMETER Path
    圧縮したいファイル、またはフォルダのパスじゃ。
    複数指定も可能じゃし、ワイルドカード（*.exe）も使えるぞ。

.PARAMETER Force
    初期状態で強制モードを有効にするフラグじゃ。
    対話モードで後から変更することも可能じゃ。

.PARAMETER Mode
    処理モードを強制指定する場合に使う。（指定しない場合は対話メニューが出る）
    Auto     : 自動判定（ファイル数1ならSerial、複数ならParallel）
    Serial   : 全ファイルをまとめてUPXに渡して順次実行（ログが見やすい・進捗バーあり）
    Parallel : CPUコアを使って並列実行（爆速・詳細GUIあり・圧縮率表示対応）

.PARAMETER Threads
    並列処理時の最大同時実行数じゃ。デフォルトはCPUのロジカルコア数。
    PCが重くなりすぎる場合は減らすと良い。

.EXAMPLE
    .\Compress-Upx.ps1 "C:\MyGame\game.exe"
    -> メニューが表示され、FキーやKキーで設定を変更してから実行できる。
#>

[CmdletBinding()]
Param(
    [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true, Position=0)]
    [string[]]$Path,

    [Alias("f")]
    [switch]$Force,
    
    [ValidateSet("Auto", "Parallel", "Serial", "Ask")]
    [string]$Mode = "Ask",

    [int]$Threads = $env:NUMBER_OF_PROCESSORS,

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

# ---------------------------------------------------------
# ファイルリストの収集
# ---------------------------------------------------------
$allFiles = @()
foreach ($p in $Path) {
    $resolvedPaths = Resolve-Path $p -ErrorAction SilentlyContinue
    if (-not $resolvedPaths) {
        Write-Warning "指定されたパスが見つからぬ： $p"
        continue
    }

    foreach ($rPath in $resolvedPaths) {
        $item = Get-Item -LiteralPath $rPath.Path
        if ($item -is [System.IO.DirectoryInfo]) {
            Write-Host "フォルダをスキャン中: $($item.FullName)" -ForegroundColor Yellow
            
            $targetExts = "*.exe", "*.dll", "*.so", "*.dat", "*.bin", "*.sys", "*.com", "*.scr", "*.cpl", "*.ax", "*.ocx"
            
            $allFiles += Get-ChildItem -Path $item.FullName -Recurse -Include $targetExts
        } else {
            $allFiles += $item
        }
    }
}

# 重複排除
$allFiles = $allFiles | Select-Object -Unique

if ($allFiles.Count -eq 0) {
    Write-Warning "処理すべきファイルが見つからんかった。"
    exit
}

# ---------------------------------------------------------
# 設定・モード決定（対話または引数）
# ---------------------------------------------------------
$executionMode = $Mode

# 初期設定
$useForce = $Force.IsPresent
$useKeep = $true

# 引数で指定されていない(Ask)場合は、ユーザーに聞く
if ($Mode -eq "Ask") {
    $loopMenu = $true
    while ($loopMenu) {
        Write-Host "`n----------------------------------------" -ForegroundColor DarkGray
        Write-Host "対象ファイル数: $($allFiles.Count) 個" -ForegroundColor Green
        
        Write-Host "現在の設定 (変更するには F か K を入力):" -ForegroundColor Yellow
        
        $fStr = if ($useForce) { "ON (強制圧縮)" } else { "OFF" }
        $kStr = if ($useKeep)  { "ON (バックアップ作成)" } else { "OFF" }
        
        Write-Host "   [F] Force : $fStr" -ForegroundColor $(if($useForce){"Red"}else{"Gray"})
        Write-Host "   [K] Keep  : $kStr" -ForegroundColor $(if($useKeep){"Green"}else{"Gray"})
        Write-Host ""
        
        Write-Host "実行モードを選択:" -ForegroundColor Cyan
        Write-Host "   [1] Auto     : 1個なら通常、複数なら並列 (デフォルト)"
        Write-Host "   [2] Serial   : 全てまとめてUPXに渡す (進捗バーあり・ログ綺麗)"
        Write-Host "   [3] Parallel : CPU全開で並列実行 (爆速・詳細GUIあり)"
        
        $input = Read-Host "   選択 [1-3, F, K] (EnterでAuto)"
        
        switch ($input.ToLower()) {
            'f' { $useForce = -not $useForce }
            'k' { $useKeep  = -not $useKeep  }
            '2' { $executionMode = 'Serial';   $loopMenu = $false }
            '3' { $executionMode = 'Parallel'; $loopMenu = $false }
            '1' { $executionMode = 'Auto';     $loopMenu = $false }
            ''  { $executionMode = 'Auto';     $loopMenu = $false }
            default { }
        }
    }
}

if ($executionMode -eq "Auto") {
    if ($allFiles.Count -gt 1) {
        $executionMode = "Parallel"
    } else {
        $executionMode = "Serial"
    }
}

# ---------------------------------------------------------
# 実行ブロック
# ---------------------------------------------------------

$commonArgs = @("--best")
if ($useKeep)  { $commonArgs += "-k" }
if ($useForce) { $commonArgs += "--force" }

# =========================================================
# Serialモード（一括渡し）
# =========================================================
if ($executionMode -eq "Serial") {
    Write-Host "`n[Serialモード] $($allFiles.Count) 個のファイルをまとめてUPXに渡すぞ..." -ForegroundColor Cyan
    Write-Host "※UPXの進捗バーが表示されるはずじゃ。" -ForegroundColor Gray

    $runArgs = $commonArgs + $allFiles.FullName

    Write-Host "   [Exec] $upxCmd (ファイルリスト...)" -ForegroundColor DarkGray
    
    & $upxCmd $runArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[成功] 全て完了したようじゃ！" -ForegroundColor Green
    } else {
        Write-Host "`n[注意] 一部または全てのファイルでエラーが出た可能性があるぞ。" -ForegroundColor Yellow
        Write-Host "ログを確認し、失敗したものは個別に設定を変えて試すなどするのじゃ。" -ForegroundColor Gray
    }
}
# =========================================================
# Parallelモード（並列ジョブ + 詳細GUIリスト）
# =========================================================
else {
    Write-Host "`n[Parallelモード] 対象: $($allFiles.Count) 個 / スレッド数: $Threads" -ForegroundColor Cyan
    Write-Host "※詳細ウィンドウを出すぞ。行をダブルクリックすると詳細ログが見れるぞ。" -ForegroundColor Gray
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- GUI構築 ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "UPX 並列圧縮マネージャ - $($allFiles.Count) Files"
    $form.Size = New-Object System.Drawing.Size(900, 500)
    $form.StartPosition = "CenterScreen"
    $form.MinimizeBox = $true
    $form.MaximizeBox = $true
    $form.TopMost = $true

    $totalProgress = New-Object System.Windows.Forms.ProgressBar
    $totalProgress.Dock = "Bottom"
    $totalProgress.Height = 20
    $totalProgress.Maximum = $allFiles.Count
    $form.Controls.Add($totalProgress)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.ReadOnly = $true
    $grid.RowHeadersVisible = $false
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    $grid.ColumnHeadersHeightSizeMode = "AutoSize"
    
    # --- カラム設定 ---
    $colName = $grid.Columns.Add("Name", "ファイル名")
    $grid.Columns[$colName].Width = 200
    
    $colSize = $grid.Columns.Add("Size", "サイズ (KB)")
    $grid.Columns[$colSize].Width = 80
    $grid.Columns[$colSize].DefaultCellStyle.Alignment = "MiddleRight"

    # 新規カラム: 圧縮率
    $colRatio = $grid.Columns.Add("Ratio", "圧縮率")
    $grid.Columns[$colRatio].Width = 70
    $grid.Columns[$colRatio].DefaultCellStyle.Alignment = "MiddleRight"

    $colStatus = $grid.Columns.Add("Status", "状態")
    $grid.Columns[$colStatus].Width = 80

    $colMessage = $grid.Columns.Add("Message", "メッセージ")
    $grid.Columns[$colMessage].AutoSizeMode = "Fill"

    $form.Controls.Add($grid)

    $grid.Add_CellDoubleClick({
        param($sender, $e)
        if ($e.RowIndex -ge 0) {
            $row = $sender.Rows[$e.RowIndex]
            if ($null -ne $row.Tag) {
                [System.Windows.Forms.MessageBox]::Show($row.Tag, "詳細ログ: " + $row.Cells[0].Value)
            }
        }
    })

    $rowMap = @{}
    $rowIndex = 0
    foreach ($f in $allFiles) {
        $sizeKB = [math]::Round($f.Length / 1KB, 0)
        # Ratioカラム(インデックス2)に空文字を入れておく
        $grid.Rows.Add($f.Name, $sizeKB, "", "待機中", "") | Out-Null
        $rowMap[$f.FullName] = $rowIndex
        $rowIndex++
    }

    $form.Show()
    $form.Refresh()

    # --- 処理開始 ---
    $queue = New-Object System.Collections.Generic.Queue[System.IO.FileInfo]
    foreach ($f in $allFiles) {
        $queue.Enqueue($f)
    }

    $runningJobs = @{}
    $finishedCount = 0
    $totalCount = $allFiles.Count
    
    $jobBlock = {
        param($exePath, $targetFile, $arguments)
        $pInfo = New-Object System.Diagnostics.ProcessStartInfo
        $pInfo.FileName = $exePath
        $pInfo.Arguments = ($arguments + "`"$targetFile`"") -join " "
        $pInfo.RedirectStandardOutput = $true
        $pInfo.RedirectStandardError = $true
        $pInfo.UseShellExecute = $false
        $pInfo.CreateNoWindow = $true
        
        $p = [System.Diagnostics.Process]::Start($pInfo)
        $p.WaitForExit()
        
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        
        return @{
            ExitCode = $p.ExitCode
            Output   = $stdout + "`n" + $stderr
            File     = $targetFile
        }
    }

    while ($queue.Count -gt 0 -or $runningJobs.Count -gt 0) {
        $ids = @($runningJobs.Keys)
        foreach ($id in $ids) {
            $job = Get-Job -Id $id
            if ($job.State -ne 'Running') {
                $result = Receive-Job -Job $job
                Remove-Job -Job $job
                $runningJobs.Remove($id)
                $finishedCount++

                $rIdx = $rowMap[$result.File]
                $grid.Rows[$rIdx].Tag = $result.Output

                if ($result.ExitCode -eq 0) {
                    # 成功時: 圧縮率をログから抽出 (正規表現)
                    $ratio = "-"
                    # 例: 1024 -> 512 50.00% ... のようなパターンを探す
                    if ($result.Output -match "\s+->\s+\d+\s+([\d\.]+%)") {
                        $ratio = $matches[1]
                    }

                    $grid.Rows[$rIdx].Cells[2].Value = $ratio
                    $grid.Rows[$rIdx].Cells[3].Value = "完了"
                    $grid.Rows[$rIdx].Cells[4].Value = "成功"
                    $grid.Rows[$rIdx].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGreen
                    
                    Write-Host "[$finishedCount/$totalCount] [成功] ($ratio) $($result.File)" -ForegroundColor Green
                } else {
                    $errMsg = "不明なエラー (ダブルクリックで詳細)"
                    if ($result.Output -match "Exception|Error|CantPack|upx:") {
                        $errMsg = ($result.Output -split "`n" | Where-Object { $_ -match "Exception|Error|CantPack|upx:" } | Select-Object -Last 1).Trim()
                    }
                    
                    $grid.Rows[$rIdx].Cells[2].Value = "-"
                    $grid.Rows[$rIdx].Cells[3].Value = "失敗"
                    $grid.Rows[$rIdx].Cells[4].Value = $errMsg
                    $grid.Rows[$rIdx].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightPink
                    
                    Write-Host "[$finishedCount/$totalCount] [失敗] $($result.File)" -ForegroundColor Red
                    Write-Host "    -> $errMsg" -ForegroundColor DarkGray
                }
                
                if ($rIdx -lt $grid.RowCount) {
                    $grid.FirstDisplayedScrollingRowIndex = $rIdx
                }
            }
        }

        while ($queue.Count -gt 0 -and $runningJobs.Count -lt $Threads) {
            $nextFile = $queue.Dequeue()
            
            $rIdx = $rowMap[$nextFile.FullName]
            $grid.Rows[$rIdx].Cells[3].Value = "圧縮中..."
            $grid.Rows[$rIdx].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow

            $job = Start-Job -ScriptBlock $jobBlock -ArgumentList $upxCmd, $nextFile.FullName, $commonArgs
            $runningJobs[$job.Id] = $nextFile.FullName
        }

        $totalProgress.Value = $finishedCount
        $form.Text = "UPX 並列圧縮 - $finishedCount / $totalCount 完了"
        [System.Windows.Forms.Application]::DoEvents()

        Start-Sleep -Milliseconds 200
    }
    
    $totalProgress.Value = $totalCount
    $form.Text = "UPX 並列圧縮 - 完了！"
    Write-Host "`nすべて完了じゃ！" -ForegroundColor Cyan
    
    Start-Sleep -Seconds 3
    $form.Close()
    $form.Dispose()
}

Write-Host "終了するにはEnterキーを押してくだされ..." -ForegroundColor Gray
Read-Host