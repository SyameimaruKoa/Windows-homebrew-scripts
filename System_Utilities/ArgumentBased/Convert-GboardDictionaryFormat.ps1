#regionヘルプ
<#
.SYNOPSIS
    GboardとGoogle日本語入力のユーザー辞書ファイル形式を相互に変換します。

.DESCRIPTION
    Gboard形式の辞書に含まれる `(タブ)ja-JP` という部分を、Google日本語入力形式の `(タブ)名詞(タブ)` に変換したり、その逆の変換を行ったりします。
    ドラッグアンドドロップでも使用できます。

.PARAMETER Path
    変換対象の辞書ファイル（.txt）のパスを指定します。必須です。

.PARAMETER Mode
    変換のモードを指定します。以下のいずれかを指定してください。
    - GboardToGInput: Gboard形式 から Google日本語入力形式 へ変換します。
    - GInputToGboard: Google日本語入力形式 から Gboard形式 へ変換します。

.PARAMETER OutPath
    変換後のファイルの出力先パスを指定します。
    指定しない場合、元のファイル名に "_converted" を付けた名前で同じフォルダに保存されます。

.PARAMETER Encoding
    読み込み/書き込み時の文字エンコーディングを指定します。
    デフォルトは "UTF8" です。

.EXAMPLE
    PS C:\> .\Convert-GboardDictionaryFormat.ps1 -Path .\my_dic.txt -Mode GboardToGInput
    'my_dic.txt' をGboard形式からGoogle日本語入力形式に変換し、'my_dic_converted.txt' として保存します。

.EXAMPLE
    PS C:\> .\Convert-GboardDictionaryFormat.ps1 -Path .\my_dic.txt -Mode GInputToGboard -OutPath .\for_gboard.txt
    'my_dic.txt' をGoogle日本語入力形式からGboard形式に変換し、'for_gboard.txt' として保存します。

.NOTES
    ファイルはタブ区切りのテキストファイルであることを想定しています。
#>
#endregion
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "変換する辞書ファイルのパス")]
    [string[]]$Path,

    [Parameter(Mandatory = $true, HelpMessage = "変換モード (GboardToGInput または GInputToGboard)")]
    [ValidateSet("GboardToGInput", "GInputToGboard")]
    [string]$Mode,

    [Parameter(Mandatory = $false, HelpMessage = "出力ファイルのパス")]
    [string]$OutPath,

    [Parameter(Mandatory = $false, HelpMessage = "ファイルのエンコーディング")]
    [string]$Encoding = "UTF8"
)

begin {
    # 変換文字列を定義
    $gboardString = "`tja-JP"
    $ginputString = "`t名詞`t"

    # モードに応じて置換前後の文字列を設定
    switch ($Mode) {
        "GboardToGInput" {
            $beforeString = $gboardString
            $afterString = $ginputString
            Write-Host "モード: Gboard => Google日本語入力" -ForegroundColor Cyan
        }
        "GInputToGboard" {
            $beforeString = $ginputString
            $afterString = $gboardString
            Write-Host "モード: Google日本語入力 => Gboard" -ForegroundColor Cyan
        }
    }
}

process {
    foreach ($filePath in $Path) {
        # ファイルの存在確認
        if (-not (Test-Path -Path $filePath -PathType Leaf)) {
            Write-Error "指定されたパスにファイルが見つかりません: $filePath"
            continue
        }

        Write-Host "処理中のファイル: $filePath" -ForegroundColor Green

        try {
            # ファイル内容を読み込み
            $content = Get-Content -Path $filePath -Encoding $Encoding -Raw

            # 文字列を置換
            $convertedContent = $content -replace [regex]::Escape($beforeString), $afterString

            # 出力パスの決定
            if ([string]::IsNullOrEmpty($OutPath)) {
                $fileInfo = Get-Item -Path $filePath
                $newFileName = "$($fileInfo.BaseName)_converted$($fileInfo.Extension)"
                $resolvedOutPath = Join-Path -Path $fileInfo.DirectoryName -ChildPath $newFileName
            } else {
                $resolvedOutPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath)
            }

            # 変換後の内容をファイルに書き込み
            Set-Content -Path $resolvedOutPath -Value $convertedContent -Encoding $Encoding -NoNewline
            
            Write-Host "変換が完了しました。出力先: $resolvedOutPath" -ForegroundColor Green

        } catch {
            Write-Error "ファイルの処理中にエラーが発生しました: $_"
        }
    }
}

end {
    Write-Host "すべての処理が完了しました。"
}
