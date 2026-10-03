<#
.SYNOPSIS
    Windows標準のOpenSSH Serverをインストールして有効化します。
.DESCRIPTION
    右クリックの「PowerShellで実行」から使用できます。必要に応じて管理者承認を要求します。
    sshdを自動起動に設定し、TCP 22の受信規則を
    作成または有効化します。既存のsshd_configは変更しません。
    インストールに再起動が必要な場合は停止するため、再起動後に再実行してください。
.PARAMETER Enable
    インストールと有効化を実行します。引数なしでは実行して結果をダイアログ表示します。
.PARAMETER Gui
    結果をダイアログ表示します。引数なしの起動時は自動で有効になります。
.PARAMETER h
    詳細ヘルプを表示します。
.PARAMETER help
    詳細ヘルプを表示します。--helpも使用できます。
.EXAMPLE
    .\Enable-OpenSSHServer.ps1 -Enable
.EXAMPLE
    .\Enable-OpenSSHServer.ps1 -WhatIf -Enable
.NOTES
    Windows PowerShell 5.1以降。管理者権限と、必要に応じてWindows Updateへの接続が必要です。
    既存設定でポートを変更している場合は、そのポートのファイアウォール規則を別途設定してください。
.LINK
    https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
#>
#region Parameters
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [switch]$Enable,
    [switch]$Gui,
    [switch]$h,
    [Alias('-help')]
    [switch]$help
)
#endregion

#region Help
if ($h -or $help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    return
}
#endregion

#region GUI Mode
if (-not $Enable) {
    $Enable = $true
    $Gui = $true
}
if ($Gui) {
    Add-Type -AssemblyName System.Windows.Forms
}
#endregion

#region Main
$ErrorActionPreference = 'Stop'
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($Gui) {
            $scriptPath = $MyInvocation.MyCommand.Path.Replace("'", "''")
            $command = "& '$scriptPath' -Enable"
            if ($WhatIfPreference) {
                $command += ' -WhatIf'
            }
            $logDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'OpenSSHSetup'
            if (-not (Test-Path -LiteralPath $logDirectory)) {
                New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
            }
            $logPath = Join-Path $logDirectory ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.log')
            $bootstrap = @'
$ErrorActionPreference = 'Stop'
$workerExitCode = 0
$transcriptStarted = $false
try {
    Start-Transcript -LiteralPath '__LOG_PATH__' -Force | Out-Null
    $transcriptStarted = $true
    $global:LASTEXITCODE = 0
    __SCRIPT_COMMAND__
    if ($LASTEXITCODE -ne 0) {
        $workerExitCode = $LASTEXITCODE
    }
    else {
        Write-Output 'OPENSSH_SETUP_COMPLETED'
    }
}
catch {
    $_ | Format-List * -Force | Out-String | Write-Output
    $workerExitCode = 1
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
exit $workerExitCode
'@
            $bootstrap = $bootstrap.Replace('__LOG_PATH__', $logPath.Replace("'", "''")).Replace('__SCRIPT_COMMAND__', $command)
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
            $powerShellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $worker = Start-Process -FilePath $powerShellPath -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) -Wait -PassThru
            try {
                $details = ''
                if (Test-Path -LiteralPath $logPath) {
                    $details = Get-Content -LiteralPath $logPath -Raw
                }
                if ($worker.ExitCode -ne 0) {
                    throw "管理者側の処理が終了コード $($worker.ExitCode) で失敗しました。`r`nログ: $logPath`r`n`r`n$details"
                }
                if ($details -notmatch 'OPENSSH_SETUP_COMPLETED') {
                    throw ("管理者側の処理の完了を確認できませんでした。ログ: $logPath" )
                }
                [Windows.Forms.MessageBox]::Show("処理が完了しました。`r`nログ: $logPath", 'OpenSSHの設定が完了しました', 'OK', 'Information') | Out-Null
            }
            finally {
                $worker.Dispose()
            }
            return
        }
        throw 'PowerShellを「管理者として実行」してから再実行してください。'
    }
    if (-not $PSCmdlet.ShouldProcess('このPC', 'OpenSSH Serverのインストール、自動起動、TCP 22の受信許可')) {
        return
    }
    $capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
    if ($capability.State -ne 'Installed') {
        $result = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
        if ($result.RestartNeeded) {
            throw 'インストールに再起動が必要です。PCを再起動し、このスクリプトを再実行してください。'
        }
    }
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd
    $rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    if ($null -eq $rule) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }
    else {
        Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True -Direction Inbound -Action Allow
        $rule | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -Protocol TCP -LocalPort 22
    }
    $service = Get-Service -Name sshd
    if ($service.Status -ne 'Running') {
        throw 'sshdの起動を確認できませんでした。'
    }
    $message = 'OpenSSH Serverを有効化しました（自動起動、TCP 22の受信許可）。'
    if ($Gui) {
        [Windows.Forms.MessageBox]::Show($message, 'OpenSSH Server', 'OK', 'Information') | Out-Null
    }
    else {
        Write-Output $message
    }
}
catch {
    if ($Gui) {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'OpenSSH Serverの有効化に失敗しました', 'OK', 'Error') | Out-Null
    }
    else {
        Write-Error $_
    }
    exit 1
}
#endregion
