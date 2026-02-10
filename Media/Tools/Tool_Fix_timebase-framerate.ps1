#Requires -Version 5.1
<#
.SYNOPSIS
  VFR動画にも対応し、ffmpegの自動判断で最適な固定FPSに変換する究極のスクリプト。
#>

# (初期設定は変更ないため省略)
try { Get-Command ffmpeg.exe -ErrorAction Stop | Out-Null } catch { Write-Host "[エラー] ffmpeg.exeが見つかりません。" -ForegroundColor Red; Read-Host "..."; exit }
if ($args.Count -eq 0) { Write-Host "動画ファイルを起動用バッチにドラッグアンドドロップしてください。" -ForegroundColor Yellow; Read-Host "..."; exit }

# --- ★対話モード選択★ ---
$selectedMode = ''
while ($selectedMode -ne '1' -and $selectedMode -ne '2') {
    Clear-Host; Write-Host "==================================================" -ForegroundColor Cyan; Write-Host "  動画修正モードを選択してください"; Write-Host "==================================================" -ForegroundColor Cyan; Write-Host
    Write-Host "  [1] 高速モード (タイムスタンプ再構築)" -ForegroundColor Yellow
    Write-Host "      軽微なエラー向け。画質劣化なし・高速。"
    Write-Host
    Write-Host "  [2] 完全モード (VFRを最適な固定FPSへ変換)" -ForegroundColor Magenta
    Write-Host "      VFR問題の根本解決。ffmpegがFPSを自動判断。処理は低速。"
    Write-Host
    $selectedMode = Read-Host "どちらのモードで処理しますか？ (1 または 2 を入力してEnter)"
}

# --- メイン処理 ---
foreach ($originalFilePath in $args) {
    # (ファイルパス処理は変更ないため省略)
    Write-Host "==================================================" -ForegroundColor Cyan
    if (-not (Test-Path $originalFilePath -PathType Leaf)) { Write-Host "[スキップ] `"$originalFilePath`" は見つかりません。" -ForegroundColor Yellow; continue }
    try { $directory = Split-Path $originalFilePath -Parent; $fileName = [System.IO.Path]::GetFileNameWithoutExtension($originalFilePath); $extension = [System.IO.Path]::GetExtension($originalFilePath); $outputDir = Join-Path -Path $directory -ChildPath "fixed"; $outputFilePath = Join-Path -Path $outputDir -ChildPath "${fileName}_fixed${extension}"; $tempFilePath = Join-Path -Path $directory -ChildPath "${fileName}_temp_$(Get-Random).ts"; if (-not (Test-Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory | Out-Null } } catch { Write-Host "[エラー] ファイルパスの処理中に問題が発生。" -ForegroundColor Red; Write-Host $_; continue }

    Write-Host "[処理開始] $($fileName)$($extension)"
    try {
        if ($selectedMode -eq '1') {
            ### 高速モード ###
            Write-Host "(1/2) タイムスタンプを再構築中... [高速モード]" -ForegroundColor Yellow
            & ffmpeg -i "$originalFilePath" -c copy -bsf:v h264_mp4toannexb -f mpegts "$tempFilePath" -y -hide_banner -loglevel error
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg(手順1)でエラーが発生" }
            Write-Host "(2/2) MP4コンテナへ再格納中..." -ForegroundColor Yellow
            & ffmpeg -i "$tempFilePath" -c copy -f mp4 "$outputFilePath" -y -hide_banner -loglevel error
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg(手順2)でエラーが発生" }
        } elseif ($selectedMode -eq '2') {
            ### ★★★究極の完全モード★★★ ###
            Write-Host "(1/1) VFRを最適な固定FPSに変換中... [完全モード]" -ForegroundColor Magenta
            Write-Host "      (ffmpegがFPSを自動選択。処理には時間がかかります)" -ForegroundColor Magenta
            # -r オプションを削除し、ffmpegの自動判断に任せる
            & ffmpeg -i "$originalFilePath" -vsync cfr -c:v libx264 -pix_fmt yuv420p -c:a copy "$outputFilePath" -y -hide_banner -loglevel error
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg(固定FPS変換)でエラーが発生" }
        }
        Write-Host "[処理完了] fixedフォルダに `"$($fileName)_fixed$($extension)`" を保存しました。" -ForegroundColor Green
    } catch { Write-Host "[エラー] $($fileName)$($extension) の処理に失敗。" -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red
    } finally { if (Test-Path $tempFilePath) { Remove-Item $tempFilePath -Force } }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "全ての処理が完了しました。"
Read-Host "何かキーを押して終了します..."