<#
.SYNOPSIS
    Downloadsの公開鍵を現在のWindowsユーザーへ登録し、登録済みの元ファイルを削除します。
.DESCRIPTION
    Downloads直下の*.pubを対象とし、各ファイルに1つのOpenSSH公開鍵があることを検証します。
    全ファイルを検証後、既存の鍵を保持して重複を除き追加します。
    保存内容とアクセス権を確認してから、内容が変わっていない元ファイルだけ削除します。
    管理者グループのユーザーはProgramData\ssh\administrators_authorized_keysへ登録します。
    この共有ファイルの鍵は他の管理者アカウントでも使用できます。管理者として実行してください。
    その他のユーザーは自身の.ssh\authorized_keysへ登録します。
    Windows標準のsshd_configの登録先を前提とします。独自のAuthorizedKeysFileには対応しません。
    引数なしでは右クリックの「PowerShellで実行」に対応し、結果をダイアログ表示します。
    この起動方法では必要な管理者承認を要求し、別アカウントに切り替わると登録を停止します。
.PARAMETER Register
    登録と元ファイルの削除を実行します。引数なしでは実行して結果をダイアログ表示します。
.PARAMETER Gui
    結果をダイアログ表示します。引数なしの起動時は自動で有効になります。
.PARAMETER ExpectedUserSid
    自動昇格時のアカウント確認用。通常は指定不要です。
.PARAMETER DownloadsPath
    対象フォルダ。省略すると現在のユーザーのDownloads既知フォルダを取得します。
.PARAMETER h
    詳細ヘルプを表示します。
.PARAMETER help
    詳細ヘルプを表示します。--helpも使用できます。
.EXAMPLE
    .\Register-OpenSSHPublicKeys.ps1 -Register
.EXAMPLE
    .\Register-OpenSSHPublicKeys.ps1 -Register -WhatIf
.EXAMPLE
    .\Register-OpenSSHPublicKeys.ps1 -Register -DownloadsPath 'D:\Downloads'
.NOTES
    Windows PowerShell 5.1以降。OpenSSHのssh-keygenが必要です。
    秘密鍵やサブフォルダ内のファイルは処理しません。SSH接続そのものの確認は行いません。
.LINK
    https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement
#>
#region Parameters
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [switch]$Register,
    [switch]$Gui,
    [string]$ExpectedUserSid,
    [string]$DownloadsPath,
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
if (-not $Register) {
    $Register = $true
    $Gui = $true
}
if ($Gui) {
    Add-Type -AssemblyName System.Windows.Forms
}
#endregion

#region Functions
function Set-KeyFileAcl {
    param ([string]$Path, [Security.Principal.SecurityIdentifier]$OwnerSid, [bool]$Administrator)
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($existingRule in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) {
        $acl.RemoveAccessRuleSpecific($existingRule)
    }
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $OwnerSid.Value) {
        $acl.SetOwner($OwnerSid)
    }
    $sids = @('S-1-5-18', 'S-1-5-32-544')
    if (-not $Administrator) {
        $sids += $OwnerSid.Value
    }
    foreach ($sid in $sids) {
        $account = New-Object Security.Principal.SecurityIdentifier($sid)
        $access = New-Object Security.AccessControl.FileSystemAccessRule($account, 'FullControl', 'Allow')
        $acl.AddAccessRule($access)
    }
    if ($PSVersionTable.PSVersion.Major -le 5) {
        [IO.File]::SetAccessControl($Path, $acl)
    }
    else {
        [IO.FileSystemAclExtensions]::SetAccessControl([IO.FileInfo]::new($Path), $acl)
    }
    $actual = Get-Acl -LiteralPath $Path
    if (-not $actual.AreAccessRulesProtected -or $actual.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $OwnerSid.Value) {
        throw '登録先の所有者またはアクセス権を確認できませんでした。元ファイルは削除しません。'
    }
    $rules = @($actual.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ($rules.Count -ne $sids.Count) {
        throw '登録先に予期しないアクセス権があります。元ファイルは削除しません。'
    }
    foreach ($rule in $rules) {
        if ($rule.IdentityReference.Value -notin $sids -or $rule.AccessControlType -ne 'Allow' -or $rule.FileSystemRights -ne 'FullControl') {
            throw '登録先のアクセス権が一致しません。元ファイルは削除しません。'
        }
    }
}
#endregion

#region Main
$ErrorActionPreference = 'Stop'
$tempKey = $null
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($ExpectedUserSid -and $identity.User.Value -ne $ExpectedUserSid) {
        throw '別の管理者アカウントに切り替わったため登録を停止しました。登録するユーザー自身のアカウントで実行してください。'
    }
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $identity.Groups.Value -contains 'S-1-5-32-544'
    if ($isAdmin -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($Gui) {
            $scriptPath = $MyInvocation.MyCommand.Path.Replace("'", "''")
            $sid = $identity.User.Value
            $command = "& '$scriptPath' -Register -ExpectedUserSid '$sid'"
            if (-not [string]::IsNullOrWhiteSpace($DownloadsPath)) {
                $folder = $DownloadsPath.Replace("'", "''")
                $command += " -DownloadsPath '$folder'"
            }
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
        throw '管理者ユーザーの登録にはPowerShellを「管理者として実行」してください。'
    }
    if ([string]::IsNullOrWhiteSpace($DownloadsPath)) {
        $folders = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
        $DownloadsPath = [Environment]::ExpandEnvironmentVariables($folders.'{374DE290-123F-4565-9164-39C4925E467B}')
        if ([string]::IsNullOrWhiteSpace($DownloadsPath)) {
            throw 'Downloadsフォルダを取得できません。-DownloadsPathで指定してください。'
        }
    }
    $files = @(Get-ChildItem -LiteralPath $DownloadsPath -Filter '*.pub' -File)
    if ($files.Count -eq 0) {
        throw '対象フォルダに*.pub公開鍵ファイルがありません。'
    }
    $keygen = (Get-Command ssh-keygen.exe -CommandType Application -ErrorAction Stop).Source
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    $sources = @()
    $tempKey = [IO.Path]::GetTempFileName()
    foreach ($file in $files) {
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "リンクの公開鍵は処理できません: $($file.FullName)"
        }
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $content = $encoding.GetString($bytes).TrimStart([char]0xFEFF).Trim()
        if ($content -notmatch '\A(ssh-[\w-]+|ecdsa-[\w-]+|sk-[\w@.-]+)\s+([A-Za-z0-9+/]+={0,2})(?:[ \t]+[^\r\n]*)?\z') {
            throw "1つのOpenSSH公開鍵として読み取れません: $($file.FullName)"
        }
        $keyId = $Matches[1] + ' ' + $Matches[2]
        [IO.File]::WriteAllText($tempKey, $content + "`n", $encoding)
        & $keygen -l -f $tempKey | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "公開鍵の検証に失敗しました: $($file.FullName)"
        }
        $sources += [pscustomobject]@{ Path = $file.FullName; Bytes = $bytes; Content = $content; KeyId = $keyId }
    }
    if ($isAdmin) {
        $target = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
        $owner = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    }
    else {
        $target = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh\authorized_keys'
        $owner = $identity.User
    }
    $directory = Split-Path -Parent $target
    foreach ($path in @($directory, $target)) {
        if (Test-Path -LiteralPath $path) {
            if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "登録先にリンクは使用できません: $path"
            }
        }
    }
    $existing = ''
    if (Test-Path -LiteralPath $target) {
        $existing = [IO.File]::ReadAllText($target, $encoding)
    }
    $updated = $existing
    foreach ($source in $sources) {
        $pattern = '(?m)^[ \t]*' + [regex]::Escape($source.KeyId) + '(?:[ \t]|\r?$)'
        if ($updated -notmatch $pattern) {
            if ($updated.Length -gt 0 -and -not $updated.EndsWith("`n")) {
                $updated += "`r`n"
            }
            $updated += $source.Content + "`r`n"
        }
    }
    if (-not $PSCmdlet.ShouldProcess($target, "$($sources.Count)個の公開鍵を登録し、検証済みの元.pubファイルを削除")) {
        return
    }
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    [IO.File]::WriteAllText($target, $updated, $encoding)
    Set-KeyFileAcl -Path $target -OwnerSid $owner -Administrator $isAdmin
    if ([IO.File]::ReadAllText($target, $encoding) -cne $updated) {
        throw '登録先の保存結果が一致しません。元ファイルは削除しません。'
    }
    foreach ($source in $sources) {
        $current = [IO.File]::ReadAllBytes($source.Path)
        if ([Convert]::ToBase64String($current) -cne [Convert]::ToBase64String($source.Bytes)) {
            throw "検証後に元ファイルが変更されました。削除しません: $($source.Path)"
        }
        Remove-Item -LiteralPath $source.Path
        Write-Output "登録済み公開鍵を削除しました: $($source.Path)"
    }
    if ($Gui) {
        [Windows.Forms.MessageBox]::Show("$($sources.Count)個の公開鍵を登録し、登録済みの元ファイルを削除しました。`r`n登録先: $target", '公開鍵の登録が完了しました', 'OK', 'Information') | Out-Null
    }
    else {
        Write-Output "公開鍵の登録先: $target"
    }
}
catch {
    if ($Gui) {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, '公開鍵の登録に失敗しました', 'OK', 'Error') | Out-Null
    }
    else {
        Write-Error $_
    }
    exit 1
}
finally {
    if ($tempKey -and (Test-Path -LiteralPath $tempKey)) {
        Remove-Item -LiteralPath $tempKey -Force -WhatIf:$false -Confirm:$false
    }
}
#endregion
