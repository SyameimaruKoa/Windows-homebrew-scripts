<#
.SYNOPSIS
    ChromeDriver の最新安定版 (win64) を自動でダウンロードし、展開します。

.DESCRIPTION
    このスクリプトは、ChromeDriver の最新安定版 (win64) を自動でダウンロード・展開します。

    [デフォルト動作 (引数なし)]
    1. PATH が通っている 'chromedriver.exe' を検索します。
    2. (見つからない場合) 個人の 'OneDrive\CUIApplication\Chrome-Driver\chromedriver.exe' を検索します。
    3. (見つからない場合) ビジネス用の OneDrive ($env:ONEDRIVE) の 'CUIApplication\Chrome-Driver\chromedriver.exe' を検索します。
    4. 
       - [アップデートモード] 1～3 で見つかった場合、その 'chromedriver.exe' を最新版に上書き（アップデート）します。
       - [ダウンロードモード] 見つからない場合、ユーザーの「ダウンロード」フォルダに最新版をダウンロード・展開します。

    [-DownloadOnly スイッチ]
    アップデートチェックをすべてスキップし、強制的に「ダウンロードモード」で実行し、ユーザーの「ダウンロード」フォルダに保存します。

.PARAMETER DownloadOnly
    このスイッチを指定すると、既存の ChromeDriver の検索（アップデートモード）を行わず、
    強制的にダウンロードモードで実行します。

.EXAMPLE
    .\Download-LatestChromeDriver.ps1
    (既存の chromedriver.exe が PATH 等にあれば自動更新、なければダウンロードフォルダに保存します)

.EXAMPLE
    .\Download-LatestChromeDriver.ps1 -DownloadOnly
    (既存のファイルがあっても無視し、ダウンロードフォルダに最新版をダウンロード・展開します)
#>
[CmdletBinding()]
param (
    [Switch]$DownloadOnly
)

# --- 1. 変数定義 ---
Write-Host "--- ChromeDriver アップデーター (v10) ---" -ForegroundColor Green
$ApiUrl = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
$targetDriverExe = $null
$isUpdateMode = $false
$downloadDir = $null # 初期化

# --- 2. 動作モード決定 (v10: OneDrive パスチェック修正) ---

if ($DownloadOnly.IsPresent) {
    # [v7] DownloadOnly スイッチが指定された場合、強制的にダウンロードモード
    Write-Host "DownloadOnly モード: アップデートチェックをスキップします。" -ForegroundColor Yellow
    $isUpdateMode = $false
    try {
        # v9 修正: GetFolderPath ではなく $env:USERPROFILE からパスを構築
        $downloadDir = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
        if (-not (Test-Path $downloadDir)) { 
            Write-Host "ダウンロードフォルダ ($downloadDir) が見つかりません。作成します。" -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $downloadDir -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "ダウンロード先: ユーザーのダウンロードフォルダ ($downloadDir) を使用します。"
    }
    catch {
        Write-Warning "ダウンロードフォルダの取得または作成に失敗しました: $($_.Exception.Message)"
        Write-Warning "フォールバック: カレントディレクトリを使用します。"
        $downloadDir = (Get-Location).Path
    }
}
else {
    # --- [v10] 従来の自動アップデートチェック (OneDrive パス修正) ---
    $isUpdateMode = $false # 初期化
    $targetDriverExe = $null

    # 1. PATHが通っているか確認 (優先度1)
    Write-Host "PATH 環境変数から chromedriver.exe を検索しています..."
    try {
        $pathResult = Get-Command chromedriver.exe -ErrorAction Stop
        if ($pathResult) {
            $targetDriverExe = $pathResult.Source
        }
    }
    catch { 
        # (見つからない場合は $targetDriverExe が $null のまま)
    }

    if ($targetDriverExe) {
        Write-Host "アップデートモード (PATH): 既存の $targetDriverExe を検出しました。" -ForegroundColor Cyan
        $isUpdateMode = $true
    }
    else {
        # 2. (PATHになければ) 次に 個人の OneDrive フォルダを確認 (優先度2)
        Write-Host "PATH 上に見つかりません。次に 個人の OneDrive\CUIApplication\Chrome-Driver を確認します。"
        $personalOneDrivePath = Join-Path -Path $env:USERPROFILE -ChildPath "OneDrive"
        $personalOneDriveTargetExe = Join-Path -Path $personalOneDrivePath -ChildPath "CUIApplication\Chrome-Driver\chromedriver.exe"

        if (Test-Path $personalOneDriveTargetExe) {
            $targetDriverExe = $personalOneDriveTargetExe
            Write-Host "アップデートモード (Personal OneDrive): 既存の $targetDriverExe を検出しました。" -ForegroundColor Cyan
            $isUpdateMode = $true
        }
        else {
            # 3. (どちらにもなければ) 次に ビジネス/学校の OneDrive フォルダを確認 (優先度3)
            Write-Host "個人の OneDrive にも見つかりません。次に ビジネス/学校の OneDrive ($env:ONEDRIVE) を確認します。"
            if (-not [string]::IsNullOrEmpty($env:ONEDRIVE) -and (Test-Path $env:ONEDRIVE)) {
                $businessOneDriveTargetExe = Join-Path -Path $env:ONEDRIVE -ChildPath "CUIApplication\Chrome-Driver\chromedriver.exe"
                
                if (Test-Path $businessOneDriveTargetExe) {
                    $targetDriverExe = $businessOneDriveTargetExe
                    Write-Host "アップデートモード (Business OneDrive): 既存の $targetDriverExe を検出しました。" -ForegroundColor Cyan
                    $isUpdateMode = $true
                }
            }
        }
    }


    # --- 最終的なモード決定 ---
    if ($isUpdateMode) {
        # アップデートモード時のダウンロード先は $env:TEMP
        Write-Host "一時ダウンロード先として $env:TEMP を使用します。"
        $downloadDir = $env:TEMP
    }
    else {
        # 3. (すべて見つからなければ) ダウンロードモード
        Write-Host "ダウンロードモード: 既知の場所に chromedriver.exe が見つかりません。" -ForegroundColor Yellow
        try {
            # v9 修正: GetFolderPath ではなく $env:USERPROFILE からパスを構築
            $downloadDir = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
            if (-not (Test-Path $downloadDir)) { 
                Write-Host "ダウンロードフォルダ ($downloadDir) が見つかりません。作成します。" -ForegroundColor Cyan
                New-Item -ItemType Directory -Path $downloadDir -Force -ErrorAction Stop | Out-Null
            }
            Write-Host "ダウンロード先: ユーザーのダウンロードフォルダ ($downloadDir) を使用します。"
        }
        catch {
            Write-Warning "ダウンロードフォルダの取得または作成に失敗しました: $($_.Exception.Message)"
            Write-Warning "フォールバック: カレントディレクトリを使用します。"
            $downloadDir = (Get-Location).Path
        }
    }
}


# --- 3. URL 取得 ---
$zipFileName = "chromedriver-win64.zip"
$zipFile = Join-Path -Path $downloadDir -ChildPath $zipFileName
$extractDirName = "chromedriver-win64" # zip 内部のディレクトリ名
$extractPath = Join-Path -Path $downloadDir -ChildPath $extractDirName
$newDriverExe = Join-Path -Path $extractPath -ChildPath "chromedriver.exe"

Write-Host "最新の Stable (win64) 版の URL を取得しています..."
try {
    $response = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing
    $stableUrl = $response.channels.Stable.downloads.chromedriver | Where-Object { $_.platform -eq 'win64' } | Select-Object -ExpandProperty url
    
    if ([string]::IsNullOrEmpty($stableUrl)) {
        throw "JSON API から win64 の URL が見つかりませんでした。"
    }
    
    Write-Host "ダウンロード URL: $stableUrl"
}
catch {
    Write-Error "API からの URL 取得に失敗しました: $($_.Exception.Message)"
    exit 1
}

# --- 4. 既存ドライバのバックアップ (アップデートモード時) ---
if ($isUpdateMode) {
    # 実行中の chromedriver.exe があれば強制終了 (アップデート失敗防止)
    $processes = Get-Process -Name "chromedriver" -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Host "既存の chromedriver.exe プロセスを検出しました。アップデートのため強制終了します。" -ForegroundColor Yellow
        $processes | Stop-Process -Force
        Start-Sleep -Seconds 2 # 終了待機
    }
}

# --- 5. ダウンロード ---
# aria2c が存在するか確認
$aria2c = Get-Command aria2c -ErrorAction SilentlyContinue
$downloadSuccess = $false

try {
    if ($aria2c) {
        Write-Host "aria2c を使用してダウンロードを開始します..."
        # v4 修正: -d (ディレクトリ) と -o (ファイル名) を分離
        & $aria2c -x16 -s16 -d $downloadDir -o $zipFileName $stableUrl
    }
    else {
        Write-Host "aria2c が見つかりません。Invoke-WebRequest を使用してダウンロードします..."
        Write-Host "(大容量ファイルの場合、時間がかかることがあります...)"
        Invoke-WebRequest -Uri $stableUrl -OutFile $zipFile -UseBasicParsing
    }
    
    if (Test-Path $zipFile) {
        $downloadSuccess = $true
    }
}
catch {
    Write-Error "ダウンロード中にエラーが発生しました: $($_.Exception.Message)"
}

if (-not $downloadSuccess) {
    Write-Error "処理中にエラーが発生しました: ダウンロードに失敗しました。ファイルが存在しません: $zipFile"
    exit 1
}

# --- 6. 展開 ---
Write-Host "ダウンロード完了。$zipFile を展開しています..."
try {
    Expand-Archive -Path $zipFile -DestinationPath $downloadDir -Force -ErrorAction Stop
}
catch {
    Write-Error "Zip ファイルの展開に失敗しました: $($_.Exception.Message)"
    # 後処理
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
    exit 1
}

# --- 7. 後処理 (Zip削除) ---
Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
Write-Host "Zip ファイルを削除しました。"

# --- 8. 配置 / 案内 ---
if ($isUpdateMode -and $targetDriverExe) {
    # --- アップデートモード ---
    Write-Host "--- ChromeDriver の自動配置 (アップデート) ---" -ForegroundColor Green
    try {
        Write-Host "配置先: $targetDriverExe"
        Write-Host "コピー元: $newDriverExe"
        
        # v8: Move-Item に -Force を追加して上書きを確実にする
        Move-Item -Path $newDriverExe -Destination $targetDriverExe -Force -ErrorAction Stop
        
        Write-Host "アップデートが完了しました。"
        Write-Host "一時ディレクトリ ($extractPath) を削除します。"
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "ファイルの配置 (上書き) に失敗しました: $($_.Exception.Message)"
        Write-Error "ダウンロードされたファイルは $extractPath に残されています。"
    }
}
else {
    # --- ダウンロードモード ---
    Write-Host "--- ChromeDriver の配置 (手動) ---" -ForegroundColor Yellow
    Write-Host "ダウンロードと展開が完了しました。"
    Write-Host "1. 以下のファイルを、PATH の通った場所に配置（移動）してください。"
    Write-Host "   (ファイル: $newDriverExe )"
    Write-Host "   (推奨配置先: C:\Windows や C:\ProgramData\chocolatey\bin など)"
    Write-Host "2. 配置後、このディレクトリに残った '$extractPath' フォルダは削除して構いません。"
}

