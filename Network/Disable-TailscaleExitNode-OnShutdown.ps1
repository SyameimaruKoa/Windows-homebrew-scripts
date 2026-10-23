<#
このスクリプトの末尾に Get-Help の説明があります。
#>

#region Parameters
param (
    [ValidateRange(1, 30)]
    [int]$TimeoutSeconds = 8,
    [switch]$h,
    [switch]$help
)
#endregion

#region Help
if ($h -or $help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}
#endregion

#region Logging
$ErrorActionPreference = 'Stop'
$logFile = $null

foreach ($directory in @(
    (Join-Path $env:ProgramData 'Windows-homebrew-scripts\Logs'),
    (Join-Path ([System.IO.Path]::GetTempPath()) 'Windows-homebrew-scripts')
)) {
    try {
        [void][System.IO.Directory]::CreateDirectory($directory)
        $candidate = Join-Path $directory 'Disable-TailscaleExitNode-OnShutdown.log'
        Add-Content -LiteralPath $candidate -Value '' -Encoding UTF8 -ErrorAction Stop
        $logFile = $candidate
        break
    }
    catch {
        continue
    }
}

function Write-ShutdownLog {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    if ($null -ne $logFile) {
        try {
            Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Warning "ログ書き込み失敗: $($_.Exception.Message)"
        }
    }
}
#endregion

#region Tailscale CLI
function Invoke-TailscaleCommand {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [int]$LimitSeconds = 8
    )

    # シャットダウンの待機を長引かせず、標準出力・標準エラーのパイプ詰まりを防ぐ。
    $base = Join-Path ([System.IO.Path]::GetTempPath()) ('tailscale-shutdown-' + [guid]::NewGuid().ToString('N'))
    $stdoutPath = $base + '.out'
    $stderrPath = $base + '.err'
    $process = $null

    try {
        $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -ErrorAction Stop
        # Start-Process の出力リダイレクト時に ExitCode が null になる不具合への対策。
        $processHandle = $process.Handle
        if (-not $process.WaitForExit($LimitSeconds * 1000)) {
            try {
                $process.Kill()
                [void]$process.WaitForExit(1000)
            }
            catch {
                Write-ShutdownLog "タイムアウト後のプロセス停止失敗: $($_.Exception.Message)" 'WARN'
            }
            throw "Tailscale CLI が $LimitSeconds 秒以内に終了しなかったのじゃ。"
        }

        $process.Refresh()
        if ($null -eq $process.ExitCode) {
            throw 'Tailscale CLI の終了コードを取得できなかったのじゃ。'
        }

        $stdout = ''
        $stderr = ''
        if (Test-Path -LiteralPath $stdoutPath) {
            $stdout = [System.IO.File]::ReadAllText($stdoutPath, [System.Text.Encoding]::UTF8)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $stderr = [System.IO.File]::ReadAllText($stderrPath, [System.Text.Encoding]::UTF8)
        }

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}
#endregion

#region Main
try {
    Write-ShutdownLog 'シャットダウン時の Exit Node 解除処理を開始するのじゃ。'
    if ($null -ne $logFile) {
        Write-ShutdownLog "ログ: $logFile"
    }

    # SYSTEM の PATH に tailscale.exe が無いこともあるため、既定のインストール先を優先。
    $tailscaleExe = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (-not (Test-Path -LiteralPath $tailscaleExe -PathType Leaf)) {
        $command = Get-Command 'tailscale.exe' -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            throw 'tailscale.exe が見つからぬ。Tailscale のインストールを確認してくれ。'
        }
        $tailscaleExe = $command.Source
    }

    # 他の Tailscale 設定は変更しない。広告する側の Exit Node も対象外。
    Write-ShutdownLog 'tailscale set --exit-node= を実行するのじゃ。'
    $result = Invoke-TailscaleCommand -Executable $tailscaleExe -Arguments @('set', '--exit-node=') -LimitSeconds $TimeoutSeconds
    if ($result.ExitCode -ne 0) {
        throw "Exit Node 解除失敗 (終了コード: $($result.ExitCode))。$($result.StdErr) $($result.StdOut)"
    }

    Write-ShutdownLog '解除コマンドが正常終了したのじゃ。Tailscale の状態を確認するぞ。'
    $statusResult = Invoke-TailscaleCommand -Executable $tailscaleExe -Arguments @('status', '--json') -LimitSeconds $TimeoutSeconds
    if ($statusResult.ExitCode -ne 0) {
        throw "設定コマンドは成功したが、状態確認に失敗 (終了コード: $($statusResult.ExitCode))。$($statusResult.StdErr)"
    }
    $status = ConvertFrom-Json -InputObject $statusResult.StdOut -ErrorAction Stop
    if ($null -ne $status.ExitNodeStatus) {
        throw '状態確認時に Exit Node がまだ有効なのじゃ。'
    }

    Write-ShutdownLog '[成功] Exit Node が無効になったことを確認したのじゃ。'
    exit 0
}
catch {
    Write-ShutdownLog "[失敗] $($_.Exception.Message)" 'ERROR'
    exit 1
}
#endregion

<#
.SYNOPSIS
    Windows のシャットダウン時に Tailscale の Exit Node 利用を解除するのじゃ。
.DESCRIPTION
    ローカルグループポリシーの「コンピューターの構成 > Windows の設定 >
    スクリプト (スタートアップ/シャットダウン) > シャットダウン」の
    PowerShell スクリプトに登録して使用する。

    Tailscale CLI で --exit-node= を設定し、状態を確認して終了する。
    他の Tailscale 設定、Exit Node の広告設定、Wi-Fi 設定は変更しない。
    外部コマンドにはタイムアウトを設け、終了処理を長時間妨げない。
    正常終了時は 0、失敗時は 1 を返す。

    実行時にユーザーへ入力を求めず、終了処理を再試行しない。
    強制電源断・クラッシュ・サービス停止済みの場合は解除を保証できない。
.PARAMETER TimeoutSeconds
    各 Tailscale CLI コマンドの最大実行時間（秒）。1～30、既定値 8。
.PARAMETER h
    Get-Help の詳細ヘルプを表示する。
.PARAMETER help
    Get-Help の詳細ヘルプを表示する。
.EXAMPLE
    .\Disable-TailscaleExitNode-OnShutdown.ps1
    手動実行で解除と状態確認を行う。登録済みなら通常シャットダウンでも実行する。
.EXAMPLE
    .\Disable-TailscaleExitNode-OnShutdown.ps1 -TimeoutSeconds 5
    CLI ごとのタイムアウトを 5 秒に短縮する。
.EXAMPLE
    .\Disable-TailscaleExitNode-OnShutdown.ps1 -h
    ヘルプを表示する。
.NOTES
    シャットダウンスクリプトは SYSTEM として実行される。
    Tailscale の Run unattended を有効にし、サービスが動く構成を推奨する。
    ログ: %ProgramData%\Windows-homebrew-scripts\Logs\Disable-TailscaleExitNode-OnShutdown.log
    書き込めない場合は %TEMP%\Windows-homebrew-scripts\ 以下を使用する。
    既定のシャットダウン設定では SYSTEM の権限で実行されるため、
    手動実行成功だけではシャットダウン時の成功を保証しない。
#>
