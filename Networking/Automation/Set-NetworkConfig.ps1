<#
.SYNOPSIS
    ネットワークインターフェースのメトリクスとプロファイルを変更するGUIツールじゃ。

.DESCRIPTION
    現在のネットワークアダプタ一覧を取得し、GUI（表形式）で表示する。
    ユーザーはメトリクス値とネットワークカテゴリ（Public/Private）を編集し、
    「適用」ボタンを押すことで一括変更できるのじゃ。

.PARAMETER h
    ヘルプを表示するのじゃ。

.PARAMETER help
    ヘルプを表示するのじゃ。

.EXAMPLE
    .\Set-NetworkConfig.ps1
    GUIを起動する。

.EXAMPLE
    .\Set-NetworkConfig.ps1 -h
    ヘルプを表示する。
#>
[CmdletBinding()]
param(
    [switch]$h,
    [switch]$help
)

#region Help Section
if ($h -or $help) {
    Get-Help $PSCommandPath -Full
    exit
}
#endregion

# 管理者権限チェック
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "これを使うには管理者権限が必要じゃ！出直してまいれ。"
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# フォーム作成
$form = New-Object System.Windows.Forms.Form
$form.Text = "ネットワーク設定変更ツール - 改修版"
$form.Size = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"

# グリッドビュー作成
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Size = New-Object System.Drawing.Size(560, 300)
$grid.Location = New-Object System.Drawing.Point(10, 10)
$grid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$grid.AllowUserToAddRows = $false
$grid.RowHeadersVisible = $false
$grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill

# カラム定義
$colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colName.Name = "Name"
$colName.HeaderText = "アダプタ名"
$colName.ReadOnly = $true
$grid.Columns.Add($colName) | Out-Null

$colIdx = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colIdx.Name = "Index"
$colIdx.HeaderText = "Index"
$colIdx.ReadOnly = $true
$colIdx.Visible = $false
$grid.Columns.Add($colIdx) | Out-Null

$colMetric = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colMetric.Name = "Metric"
$colMetric.HeaderText = "メトリクス (自動=0)"
$grid.Columns.Add($colMetric) | Out-Null

$colProfile = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
$colProfile.Name = "Profile"
$colProfile.HeaderText = "プロファイル"
$colProfile.Items.Add("Public") | Out-Null
$colProfile.Items.Add("Private") | Out-Null
$colProfile.Items.Add("DomainAuthenticated") | Out-Null
$grid.Columns.Add($colProfile) | Out-Null

# データ取得と投入（ここを修正したぞ）
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
foreach ($adapter in $adapters) {
    # エラーが出ても止まらぬよう SilentlyContinue を追加じゃ
    $ipIf = Get-NetIPInterface -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $profile = Get-NetConnectionProfile -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
    
    $row = $grid.Rows.Add()
    $grid.Rows[$row].Cells["Name"].Value = $adapter.Name
    $grid.Rows[$row].Cells["Index"].Value = $adapter.InterfaceIndex
    # ipIfが取れなかった場合は空欄にする
    $grid.Rows[$row].Cells["Metric"].Value = if ($ipIf) { $ipIf.InterfaceMetric } else { "" }
    $grid.Rows[$row].Cells["Profile"].Value = if ($profile) { $profile.NetworkCategory.ToString() } else { "" }
}

# 適用ボタン
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "変更を適用する"
$btnApply.Size = New-Object System.Drawing.Size(120, 30)
$btnApply.Location = New-Object System.Drawing.Point(450, 320)
$btnApply.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$btnApply.Add_Click({
        foreach ($row in $grid.Rows) {
            $idx = $row.Cells["Index"].Value
            $metric = $row.Cells["Metric"].Value
            $cat = $row.Cells["Profile"].Value
        
            try {
                if ($idx) {
                    # メトリクスの適用
                    if ($metric -match "^\d+$") {
                        # IPv4インターフェースがあるか確認してからセットする
                        $targetIf = Get-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue
                        if ($targetIf) {
                            Set-NetIPInterface -InterfaceIndex $idx -InterfaceMetric $metric -ErrorAction Stop
                        }
                    }
                
                    # プロファイルの適用
                    if ($cat -and $cat -ne "") {
                        $current = Get-NetConnectionProfile -InterfaceIndex $idx -ErrorAction SilentlyContinue
                        if ($current -and $current.NetworkCategory -ne $cat) {
                            Set-NetConnectionProfile -InterfaceIndex $idx -NetworkCategory $cat -ErrorAction Stop
                        }
                    }
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("エラーじゃ！ アダプタ: $($row.Cells["Name"].Value)`n$($_.Exception.Message)", "警告", 0, 48)
            }
        }
        [System.Windows.Forms.MessageBox]::Show("処理が完了したぞ。", "完了", 0, 64)
        # フォームを再描画して値を更新したいならここで再取得処理を入れるが、今回は閉じるまでそのままとする
    })

$form.Controls.Add($grid)
$form.Controls.Add($btnApply)
$form.ShowDialog() | Out-Null