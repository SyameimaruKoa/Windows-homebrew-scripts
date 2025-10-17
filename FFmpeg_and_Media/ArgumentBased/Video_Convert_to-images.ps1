#region ヘルプ
<#
.SYNOPSIS
    動画から静止画を連番で書き出します。

.DESCRIPTION
    指定した動画ファイルから、PNG もしくは JPG の連番画像を出力します。
    任意でカット範囲（-ss / -to）を設定し、フレームレートを指定してJPG出力も可能です。

.PARAMETER files
    ドラッグ＆ドロップで渡された動画ファイル配列。

.EXAMPLE
    PS> .\Video_Convert_to-images.ps1 video.mp4
    対話的に設定を確認し、<video>_images/ に画像を書き出します。

.NOTES
    ・ffmpeg が PATH に通っている必要があります。
#>
#endregion

# --- 初期設定 ---
# このスクリプトに渡されたファイルパスを一つずつ処理する
Param($files)

# --- 事前チェック ---
if ($files.Count -eq 0) {
    Write-Host "[エラー] 動画ファイルが指定されていません。" -ForegroundColor Red
    Write-Host "使い方: 動画ファイルをbatファイルのアイコンにドラッグ＆ドロップしてください。"
    Read-Host "何かキーを押して終了します"
    exit
}

# --- 最初の質問 (カットするかどうか) ---
$shouldCut = $false
while ($true) {
    $choice = Read-Host "動画をカットしますか？ (Y/N)"
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        $shouldCut = $true
        break
    } elseif ($choice -eq 'n' -or $choice -eq 'N') {
        break
    } else {
        Write-Host "YかNで入力してください。" -ForegroundColor Yellow
    }
}

# --- メインループ (ドラッグ&ドロップされたファイルを一つずつ処理) ---
foreach ($filePath in $files) {
    # ファイル名やパス情報を取得
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    $parentPath = Split-Path $filePath

    # 出力ディレクトリを作成
    $outputDir = Join-Path -Path $parentPath -ChildPath "${baseName}_images"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }

    Write-Host "`n--- '$baseName' の処理を開始します ---" -ForegroundColor Cyan

    # ffmpegに渡す引数を準備
    $ffmpegArgs = New-Object System.Collections.ArrayList

    # --- カット処理 ---
    if ($shouldCut) {
        Write-Host "`n[$baseName] のカット情報を入力してください。"
        $startTime = Read-Host "開始位置 (例: 00:01:23.456)"
        $endTime = Read-Host "終了位置 (例: 00:02:00.000)"
        
        if (-not [string]::IsNullOrWhiteSpace($startTime) -and -not [string]::IsNullOrWhiteSpace($endTime)) {
            $ffmpegArgs.Add("-ss") | Out-Null
            $ffmpegArgs.Add($startTime) | Out-Null
            $ffmpegArgs.Add("-to") | Out-Null
            $ffmpegArgs.Add($endTime) | Out-Null
        }
    }

    # 入力ファイル指定
    $ffmpegArgs.Add("-i") | Out-Null
    $ffmpegArgs.Add($filePath) | Out-Null

    # --- 画像抽出処理 ---
    $extractionChoice = 0
    while ($true) {
        $extractionChoice = Read-Host "`n抽出方法を選んでください [1: 全フレーム(PNG), 2: フレームレート指定(JPG)]"
        if ($extractionChoice -eq '1' -or $extractionChoice -eq '2') {
            break
        } else {
            Write-Host "1か2で入力してください。" -ForegroundColor Yellow
        }
    }

    if ($extractionChoice -eq '2') {
        # フレームレート指定 (JPG)
        $framerate = Read-Host "1秒あたりのフレーム数を入力してください"
        Write-Host "`n[$baseName] を[${framerate}fps]で画像化(JPG)します..." -ForegroundColor Green
        
        $ffmpegArgs.Add("-r") | Out-Null
        $ffmpegArgs.Add($framerate) | Out-Null
        $ffmpegArgs.Add("-q:v") | Out-Null
        $ffmpegArgs.Add("2") | Out-Null
        ## ▼▼▼ 修正箇所1: 余計なシングルクォートを削除 ▼▼▼
        $ffmpegArgs.Add("$outputDir\$($baseName)_%09d.jpg") | Out-Null

    } else {
        # 全フレーム (PNG)
        Write-Host "`n[$baseName] を全フレームで画像化(PNG)します..." -ForegroundColor Green
        ## ▼▼▼ 修正箇所2: 余計なシングルクォートを削除 ▼▼▼
        $ffmpegArgs.Add("$outputDir\$($baseName)_%09d.png") | Out-Null
    }

    # --- FFmpegの実行 ---
    try {
        & ffmpeg $ffmpegArgs
        Write-Host "`n[$baseName] の処理が正常に完了しました。" -ForegroundColor Green
    } catch {
        Write-Host "`n[エラー] ffmpegの実行中にエラーが発生しました。" -ForegroundColor Red
        Write-Host $_
    }
}

Write-Host "`n--- すべての処理が完了しました ---" -ForegroundColor Cyan