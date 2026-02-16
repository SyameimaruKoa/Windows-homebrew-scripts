# Remote_Reconnect-Demucs_v2.ps1
# (Shift-JISまたはUTF-8で保存するのじゃ)

#regionヘルプ
<#
.SYNOPSIS
    リモートサーバーで既に起動中のJupyter Lab(Colab)コンテナに再接続し、ポートフォワーディングを開始するスクリプトじゃ。

.DESCRIPTION
    このスクリプトは、コンテナの再起動を行わずに接続のみを確立するぞ。
    以下の手順を自動で実行するのじゃ。
    1. リモートサーバー '2s' にSSH接続する。
    2. 起動中のコンテナに対し、`jupyter server list` を実行して、現在の接続用トークンを直接取得する。
    3. 取得したトークンから接続URLを組み立て、クリップボードにコピーする。
    4. '2s' へのSSHポートフォワーディング（指定ポート）を開始し、バックグラウンドで実行する。
    5. ColabノートブックのURLを既定のブラウザで（再度）開く。
    6. スクリプトはポートフォワーディングを維持したまま、ユーザーのキー入力を待つ。
    7. 何かキーが押されると、バックグラウンドのSSHポートフォワーディング用プロセスを終了させてから、スクリプトを閉じる。

.PARAMETER help
    このヘルプを表示します。

.EXAMPLE
    .\Remote_Reconnect-Demucs_v2.ps1
    スクリプトを実行すると、自動的に再接続処理が開始される。
    ブラウザでColabの「ローカルランタイムに接続」ダイアログに、コピーされたURLを貼り付けるのじゃ。
#>
#endregion

param(
    [Parameter(Mandatory = $false, HelpMessage = "ヘルプを表示します。")]
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit
}

# ----- 設定項目 (元スクリプトと同じじゃ) -----

# SSH接続先ホスト名 (ssh configで設定した名前じゃ)
$sshHost = "2s"

# Colabのdocker-compose.ymlがあるディレクトリ
$remoteDir = "/home/koa-ubuntu/Colab-docker"

# docker-compose.ymlに定義されているサービス名
$serviceName = "colab-runtime"

# ブラウザで開きたいColabノートブックのURL
$colabNotebookUrl = "https://colab.research.google.com/gist/SyameimaruKoa/8b9c42bd3ddccfe8512376e8a43a7633/hybrid-demucs-music-source-separation.ipynb"

# ローカル側とリモート側でフォワーディングするポート
$port = 9000

# --------------------

try {
    Write-Host "リモートサーバー($sshHost)で起動中のコンテナからトークンを取得するぞ..." -ForegroundColor Yellow
    
    # 起動したコンテナで `jupyter server list` を実行し、接続情報を取得する
    $sshGetTokenCommand = "cd $remoteDir; docker compose exec $serviceName jupyter server list"
    $serverListOutput = ssh $sshHost $sshGetTokenCommand
    
    # 実行結果から正規表現でトークンだけを抜き出す
    $match = $serverListOutput | Select-String -Pattern "token=([a-f0-9]+)"

    if ($match) {
        # マッチした部分からトークンの値を取得
        $token = $match.Matches[0].Groups[1].Value
        # 正しいURLを組み立てる
        $localUrl = "http://localhost:$port/?token=$token"
        
        Write-Host "トークンの取得に成功したぞ！" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "トークンが見つけられなかったわい。実行結果を確認せい。" -ForegroundColor Red
        Write-Host "コンテナが起動していない可能性もあるぞ。" -ForegroundColor Red
        Write-Host "--- `jupyter server list` の実行結果 ---"
        $serverListOutput
        Write-Host "------------------------------------"
        throw "トークン取得失敗"
    }

    # クリップボードにコピー (そなたの要望通り、残しておるぞ)
    Set-Clipboard -Value $localUrl
    Write-Host ""
    Write-Host "接続URLをクリップボードにコピーしたぞ！" -ForegroundColor Cyan
    Write-Host $localUrl -ForegroundColor White
    Write-Host ""

    # ポートフォワーディング用のSSH接続をバックグラウンドで開始
    Write-Host "SSHポートフォワーディングを開始する... (localhost:$port -> ${sshHost}:$port)" -ForegroundColor Yellow
    $sshArgs = "-N -L $($port):localhost:$($port) $sshHost"
    $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -PassThru -WindowStyle Hidden

    Write-Host "ポートフォワーディングが有効になったぞ。" -ForegroundColor Green
    Write-Host ""

    # 【変更点】指定されたColabノートブックを再度開く
    Write-Host "DemucsのColabノートブックをブラウザで開くのう..." -ForegroundColor Yellow
    Start-Process $colabNotebookUrl

    Write-Host ""
    Write-Host "------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "再接続の準備完了じゃ！" -ForegroundColor Magenta
    Write-Host "新しく開いたタブで「ローカルランタイムに接続」を選び、" -ForegroundColor Magenta
    Write-Host "クリップボードにコピーされたURLを貼り付けて接続するのじゃ。" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "このウィンドウで何かキーを押すと、SSHポートフォワーディングを終了するぞ。" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------------" -ForegroundColor Magenta

    # ユーザーの入力を待つ
    [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

}
catch {
    Write-Host ""
    Write-Host "エラーが発生したため、処理を中断したのじゃ。" -ForegroundColor Red
    # エラー内容を表示
    Write-Error $_
}
finally {
    # スクリプト終了時に、バックグラウンドのSSHプロセスがもし生きていたら終了させる
    if ($sshProcess -and !(Get-Process -Id $sshProcess.Id -ErrorAction SilentlyContinue).HasExited) {
        Write-Host ""
        Write-Host "SSHポートフォワーディング接続を切断する..." -ForegroundColor Yellow
        Stop-Process -Id $sshProcess.Id -Force
        Write-Host "切断完了じゃ。お疲れ様じゃったな。" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "スクリプトを終了するのじゃ。"
    }
}