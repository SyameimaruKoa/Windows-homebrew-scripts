<#
.SYNOPSIS
    GboardとGoogle日本語入力のユーザー辞書ファイル形式を相互に変換するのじゃ。

.DESCRIPTION
    このスクリプトは、Gboardのユーザー辞書エクスポートファイル（TSV形式）と、
    Google日本語入力のユーザー辞書エクスポートファイル（TSV形式）のフォーマットを相互に変換するのじゃ。
    具体的には、Gboard形式の「ja-JP」とGoogle日本語入力形式の「品詞なし」の部分をタブ文字ごと置換する。

.PARAMETER Path
    変換したい辞書ファイルのパスを指定するのじゃ。この引数は必須じゃぞ。

.EXAMPLE
    PS C:\> .\Convert-GboardDictionary.ps1 -Path "C:\temp\dictionary.txt"

    上記のように実行すると、対話形式で変換方向を選択できる。
    処理が完了すると、"C:\temp\dictionary_converted.txt" のような名前で変換後のファイルが出力されるのじゃ。

.NOTES
    作者: わっち
    バージョン: 1.1
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

# ファイルの存在確認
if (-not (Test-Path -Path $Path -PathType Leaf)) {
    Write-Error "指定されたファイルが見つからんのじゃ！ パスを確認せい！: `"$Path`""
    return
}

$beforeString = ""
$afterString = ""

# ユーザーが正しい選択をするまでループする
:MenuLoop while ($true) { # <== 【修正点1】ループに :MenuLoop という名前を付けた
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
    # 出力用のファイルパスを生成する
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [System.IO.Path]::GetExtension($Path)
    $newPath = Join-Path -Path $directory -ChildPath "${fileName}_converted${extension}"

    Write-Host "`nファイルを処理中じゃ... しばし待たれよ。"
    
    # ファイルをUTF-8で読み込み、置換処理を行い、新しいファイルへUTF-8で書き込む
    (Get-Content -Path $Path -Encoding UTF8) | ForEach-Object {
        $_ -replace [regex]::Escape($beforeString), $afterString
    } | Set-Content -Path $newPath -Encoding UTF8

    Write-Host "処理が完了したぞ！" -ForegroundColor Green
    Write-Host "出力ファイル: `"$newPath`""

} catch {
    Write-Error "ファイルの処理中にエラーが発生したのじゃ: $_"
}
#endregion