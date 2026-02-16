<#
.SYNOPSIS
    GboardとGoogle日本語入力のユーザー辞書ファイル形式を相互に変換するのじゃ。ZIP対応版じゃぞ。

.DESCRIPTION
    このスクリプトは、Gboardのユーザー辞書エクスポートファイル（TSV形式）と、
    Google日本語入力のユーザー辞書エクスポートファイル（TSV形式）のフォーマットを相互に変換するのじゃ。
    通常はファイルと同じ場所に変換ファイルを出力するが、ZIPファイルを指定した場合は
    内部の「dictionary.txt」を変換し、ユーザーの「ダウンロード」フォルダに出力するのじゃ。

.PARAMETER Path
    変換したい辞書ファイル（.txt）またはZIPファイル（.zip）のパスを指定するのじゃ。必須じゃぞ。

.EXAMPLE
    PS C:\> .\Convert-GboardDictionary.ps1 -Path "C:\temp\archive.zip"
    
    ZIPファイルを指定した場合、中身の dictionary.txt を変換して
    C:\Users\[User]\Downloads\archive_converted.txt に出力する。

.NOTES
    作者: わっち
    バージョン: 1.2
    文字コードはUTF-8として処理するからのう。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "変換対象のファイルパスを指定してくだされ。")]
    [string]$Path
)

#region 変換メニュー表示と選択
function Show-Menu {
    Write-Host "-----------------------------------------"
    Write-Host " Gboard・Google日本語入力 辞書変換"
    Write-Host "-----------------------------------------"
    Write-Host "変換方向を選択するのじゃ"
    Write-Host "  1: Gboard → Google日本語入力"
    Write-Host "  2: Google日本語入力 → Gboard"
    Write-Host "  Q: 終了"
    Write-Host "-----------------------------------------"
}

if (-not (Test-Path -Path $Path -PathType Leaf)) {
    Write-Error "指定されたファイルが見つからんのじゃ！ パスを確認せい！: `"$Path`""
    return
}

# ZIP判定とパスの準備
$isZip = [System.IO.Path]::GetExtension($Path).ToLower() -eq ".zip"
$processPath = $Path
$outputPath = $null
$tempDir = $null

if ($isZip) {
    Write-Host "ZIPファイルを受け取ったぞ。展開して中身を確認するのじゃ..."
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
    try {
        Expand-Archive -LiteralPath $Path -DestinationPath $tempDir -Force -ErrorAction Stop
    } catch {
        Write-Error "ZIPの展開に失敗したわ！壊れておらぬか？: $_"
        return
    }
    
    $processPath = Join-Path $tempDir "dictionary.txt"
    if (-not (Test-Path $processPath)) {
        Write-Error "ZIPの中に 'dictionary.txt' が見つからんぞ！ 構造を確認せい！"
        Remove-Item -Path $tempDir -Recurse -Force
        return
    }

    $downloadsDir = Join-Path $env:USERPROFILE "Downloads"
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $outputPath = Join-Path $downloadsDir "${fileName}_converted.txt"
}

$beforeString = ""
$afterString = ""

:MenuLoop while ($true) {
    Show-Menu
    $choice = Read-Host ">> 番号を入力してくだされ"

    switch ($choice) {
        '1' {
            $beforeString = "`tja-JP"
            $afterString = "`t品詞なし`t"
            break MenuLoop
        }
        '2' {
            $beforeString = "`t品詞なし`t"
            $afterString = "`tja-JP"
            break MenuLoop
        }
        'q' {
            Write-Host "処理を中断したのじゃ。"
            if ($tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
            return
        }
        default {
            Write-Host "喝！ 1, 2, または Q のいずれかを入力するのじゃ！" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
#endregion

#region ファイルの読み込み・置換・書き込み処理
try {
    # ZIPでない場合は元のロジックで出力パスを生成
    if (-not $isZip) {
        $directory = [System.IO.Path]::GetDirectoryName($Path)
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $extension = [System.IO.Path]::GetExtension($Path)
        $outputPath = Join-Path -Path $directory -ChildPath "${fileName}_converted${extension}"
    }

    Write-Host "`nファイルを処理中じゃ... しばし待たれよ。"
    
    (Get-Content -Path $processPath -Encoding UTF8) | ForEach-Object {
        $_ -replace [regex]::Escape($beforeString), $afterString
    } | Set-Content -Path $outputPath -Encoding UTF8

    Write-Host "処理が完了したぞ！" -ForegroundColor Green
    Write-Host "出力ファイル: `"$outputPath`""

} catch {
    Write-Error "ファイルの処理中にエラーが発生したのじゃ: $_"
} finally {
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}
#endregion
