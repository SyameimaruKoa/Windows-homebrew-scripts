<#
.SYNOPSIS
    Windows標準のOpenSSH Serverをインストールして有効化します。
.DESCRIPTION
    管理者として実行してください。sshdを自動起動に設定し、TCP 22の受信規則を
    作成または有効化します。既存のsshd_configは変更しません。
    インストールに再起動が必要な場合は停止するため、再起動後に再実行してください。
.PARAMETER Enable
    インストールと有効化を実行します。引数なしではヘルプを表示します。
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
    [switch]$h,
    [Alias('-help')]
    [switch]$help
)
#endregion

#region Help
if ($h -or $help -or -not $Enable) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    return
}
#endregion

#region Main
$ErrorActionPreference = 'Stop'
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
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
    Write-Output 'OpenSSH Serverを有効化しました（自動起動、TCP 22の受信許可）。'
}
catch {
    Write-Error $_
    exit 1
}
#endregion
