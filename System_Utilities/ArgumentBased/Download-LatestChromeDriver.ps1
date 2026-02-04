<#
.SYNOPSIS
    ChromeDriver の最新安定版 (win64) を自動でダウンロードし、展開・更新します。

.DESCRIPTION
    このスクリプトは、ChromeDriver の最新安定版 (win64) を自動でダウンロードし、
    システム内に存在する既存の chromedriver.exe を検出して一括更新します。

    [更新対象の検索順序と挙動]
    以下の場所をすべてチェックし、存在するものは**すべて**更新します。
    1. PATH が通っている場所
    2. ユーザープロファイル配下の 'OneDrive\CUIApplication\Chrome-Driver\chromedriver.exe'
    3. 環境変数 ONEDRIVE 配下の 'CUIApplication\Chrome-Driver\chromedriver.exe'
    4. [NEW] 'OneDrive\PortableApps\pixiv_next\chromedriver.exe' (指定パス)

    [ロック解除機能]
    更新時にファイルが使用中で書き込めない場合、自動的に 'chromedriver' および 'chrome' プロセスを
    強制終了して再試行します。

    [-DownloadOnly スイッチ]
    アップデートチェックをすべてスキップし、強制的に「ダウンロードモード」で実行し、
    ユーザーの「ダウンロード」フォルダに保存します。

.PARAMETER DownloadOnly
    既存の検索を行わず、ダウンロードのみを行います。

.EXAMPLE
    .\Download-LatestChromeDriver.ps1
    (検出されたすべての chromedriver.exe を更新します)
#>
[CmdletBinding()]
param (
    [Switch]$DownloadOnly
)

# --- ヘルプ表示用 (引数なしでも実行されるが、念のため) ---
# Get-Help .\Download-LatestChromeDriver.ps1 -Full で詳細を表示

# --- 1. 変数定義 ---
Write-Host "--- ChromeDriver アップデーター (v11: Multi-Target & Auto-Kill) ---" -ForegroundColor Green
$ApiUrl = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
$updateTargets = @() # 更新対象のリスト
$isUpdateMode = $false
$downloadDir = $null

# --- 2. 動作モードと対象の決定 ---

if ($DownloadOnly.IsPresent) {
    Write-Host "DownloadOnly モード: アップデートチェックをスキップします。" -ForegroundColor Yellow
    $isUpdateMode = $false
    $downloadDir = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
}
else {
    Write-Host "システム内の chromedriver.exe を検索しています..." -ForegroundColor Cyan

    # 1. PATH チェック
    try {
        $pathResult = Get-Command chromedriver.exe -ErrorAction SilentlyContinue
        if ($pathResult) {
            $pathStr = $pathResult.Source
            if ($pathStr -and (Test-Path $pathStr)) {
                Write-Host "  [検出] PATH: $pathStr"
                $updateTargets += $pathStr
            }
        }
    }
    catch {}

    # 2. 個人 OneDrive (標準)
    $personalOneDriveExe = Join-Path -Path $env:USERPROFILE -ChildPath "OneDrive\CUIApplication\Chrome-Driver\chromedriver.exe"
    if (Test-Path $personalOneDriveExe) {
        Write-Host "  [検出] OneDrive (Personal): $personalOneDriveExe"
        $updateTargets += $personalOneDriveExe
    }

    # 3. ビジネス OneDrive
    if (-not [string]::IsNullOrEmpty($env:ONEDRIVE)) {
        $bizOneDriveExe = Join-Path -Path $env:ONEDRIVE -ChildPath "CUIApplication\Chrome-Driver\chromedriver.exe"
        if (Test-Path $bizOneDriveExe) {
            Write-Host "  [検出] OneDrive (Business): $bizOneDriveExe"
            $updateTargets += $bizOneDriveExe
        }
    }

    # 4. [NEW] 指定された PortableApps パス
    # C:\Users\kouki\... を動的に解決するため $env:USERPROFILE を使用
    $portablePath = Join-Path -Path $env:USERPROFILE -ChildPath "OneDrive\PortableApps\pixiv_next\chromedriver.exe"
    if (Test-Path $portablePath) {
        Write-Host "  [検出] PortableApps: $portablePath"
        $updateTargets += $portablePath
    }

    # 重複排除（PATHと実体パスが被る場合など）
    $updateTargets = $updateTargets | Select-Object -Unique

    if ($updateTargets.Count -gt 0) {
        $isUpdateMode = $true
        Write-Host "合計 $($updateTargets.Count) 箇所の更新対象が見つかりました。" -ForegroundColor Cyan
        $downloadDir = $env:TEMP
    }
    else {
        Write-Host "更新対象が見つかりません。ダウンロードモードで実行します。" -ForegroundColor Yellow
        $downloadDir = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
    }
}

# ダウンロード先ディレクトリの準備
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

# --- 3. URL 取得 ---
$zipFileName = "chromedriver-win64.zip"
$zipFile = Join-Path -Path $downloadDir -ChildPath $zipFileName
$extractDirName = "chromedriver-win64"
$extractPath = Join-Path -Path $downloadDir -ChildPath $extractDirName
$newDriverExe = Join-Path -Path $extractPath -ChildPath "chromedriver.exe"

Write-Host "最新の Stable (win64) 版の URL を取得中..."
try {
    $response = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing
    $stableUrl = $response.channels.Stable.downloads.chromedriver | Where-Object { $_.platform -eq 'win64' } | Select-Object -ExpandProperty url
    
    if ([string]::IsNullOrEmpty($stableUrl)) { throw "URLが見つかりません。" }
    Write-Host "URL: $stableUrl"
}
catch {
    Write-Error "URL取得失敗: $($_.Exception.Message)"
    exit 1
}

# --- 4. 事前プロセス終了 (念のため) ---
if ($isUpdateMode) {
    Write-Host "更新準備: 実行中の chromedriver を終了しています..."
    Get-Process -Name "chromedriver" -ErrorAction SilentlyContinue | Stop-Process -Force
}

# --- 5. ダウンロード ---
Write-Host "ダウンロード開始..."
try {
    $aria2c = Get-Command aria2c -ErrorAction SilentlyContinue
    if ($aria2c) {
        & $aria2c -x16 -s16 -d $downloadDir -o $zipFileName $stableUrl
    }
    else {
        Invoke-WebRequest -Uri $stableUrl -OutFile $zipFile -UseBasicParsing
    }
}
catch {
    Write-Error "ダウンロード失敗: $($_.Exception.Message)"
    exit 1
}

if (-not (Test-Path $zipFile)) {
    Write-Error "ファイルが保存されていません: $zipFile"
    exit 1
}

# --- 6. 展開 ---
Write-Host "展開中..."
try {
    Expand-Archive -Path $zipFile -DestinationPath $downloadDir -Force -ErrorAction Stop
}
catch {
    Write-Error "展開失敗: $($_.Exception.Message)"
    Remove-Item $zipFile -Force
    exit 1
}

# Zip削除
Remove-Item $zipFile -Force -ErrorAction SilentlyContinue

# --- 7. 配置 / 更新処理 (メイン) ---

if ($isUpdateMode) {
    Write-Host "--- 更新処理開始 ---" -ForegroundColor Green
    
    foreach ($target in $updateTargets) {
        Write-Host "対象: $target を更新します..."
        
        $maxRetries = 3
        $retryCount = 0
        $success = $false

        while (-not $success -and $retryCount -lt $maxRetries) {
            try {
                # 上書き試行
                Copy-Item -Path $newDriverExe -Destination $target -Force -ErrorAction Stop
                Write-Host "  -> 更新成功！" -ForegroundColor Cyan
                $success = $true
            }
            catch {
                $retryCount++
                Write-Warning "  書き込み失敗 (試行 $retryCount/$maxRetries): ファイルがロックされている可能性があります。"
                
                # 自動対処ロジック: Chrome も巻き込んで落とす
                Write-Host "  [自動対処] Chrome および ChromeDriver プロセスを強制終了してロック解除を試みます..." -ForegroundColor Red
                Get-Process -Name "chromedriver" -ErrorAction SilentlyContinue | Stop-Process -Force
                Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force
                
                Start-Sleep -Seconds 2
            }
        }

        if (-not $success) {
            Write-Error "  -> 更新失敗: $target (Chromeを終了しても書き込めませんでした。権限を確認してください)"
        }
    }

    # 後始末
    Write-Host "一時ファイルを削除します..."
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "すべての処理が完了しました。" -ForegroundColor Green
}
else {
    # ダウンロードモード
    Write-Host "--- ダウンロード完了 ---" -ForegroundColor Yellow
    Write-Host "ファイルは以下にあります:"
    Write-Host "  $newDriverExe"
    Write-Host "手動で必要な場所に配置してください。"
}