<#
.SYNOPSIS
    Gboard のユーザー辞書（TSV）を Google 日本語入力向けに変換する一方向ツール。

.DESCRIPTION
    このスクリプトは Gboard のエクスポートファイル（TSV 形式）を入力とし、
    Google 日本語入力の辞書に適した形式へ変換する簡易ツールじゃ。
    変換内容は一方向のみで、行中のタブ付きの言語タグ "ja-JP"（"\tja-JP"）を
    単純に除去する操作を行う。ZIP を指定した場合は内部の "dictionary.txt" を変換し、
    出力は ZIP のファイル名に "_converted.txt" を付けてユーザーの Downloads フォルダへ保存する。

.PARAMETER Path
    変換対象の辞書ファイル（.txt）または ZIP ファイル（.zip）を指定する。必須。

.EXAMPLE
    PS C:\> .\File_Convert-GboardDictionary.ps1 -Path "C:\temp\gboard_dictionary.txt"

    PS C:\> .\File_Convert-GboardDictionary.ps1 -Path "C:\temp\archive.zip"
    ZIP を指定した場合、内部の dictionary.txt を変換して
    C:\Users\[User]\Downloads\archive_converted.txt に出力する。

.NOTES
    作者: わっち
    バージョン: 1.3
    文字コードは UTF-8 で処理する。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "変換対象のファイルパスを指定してくだされ。")]
    [string]$Path
)

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
    }
    catch {
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

# 一方向変換: Gboard → Google日本語入力
# 単純にタブ付きの "ja-JP" を除去する (例: "\tja-JP" -> "")
$beforeString = "`tja-JP"
$afterString = ""

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

}
catch {
    Write-Error "ファイルの処理中にエラーが発生したのじゃ: $_"
}
finally {
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}
#endregion
