#regionヘルプ
<#
.SYNOPSIS
    リモートサーバーにSSH接続し、Jupyter Lab(Colab)コンテナを起動して、ポートフォワーディングを開始するスクリプトじゃ。

.DESCRIPTION
    以下の手順を自動で実行するぞ。
    1. リモートサーバー '2s' にSSH接続し、既存のColabコンテナを停止・削除する (docker compose down)。
    2. Colabコンテナをデタッチモードで再起動する (docker compose up -d)。
    3. 起動したコンテナに対し、`jupyter server list` を実行して、接続用トークンを直接取得する。
    4. 取得したトークンから接続URLを組み立て、クリップボードにコピーする。
    5. '2s' へのSSHポートフォワーディング（8888:localhost:8888）を開始し、バックグラウンドで実行する。
    6. 事前に指定されたDemucsのGoogle ColabノートブックURLを既定のブラウザで開く。
    7. スクリプトはポートフォワーディングを維持したまま、ユーザーのキー入力を待つ。
    8. 何かキーが押されると、バックグラウンドのSSHポートフォワーディング用プロセスを終了させてから、スクリプトを閉じる。
       (サーバー上のColabコンテナは起動したままじゃ)

.PARAMETER help
    このヘルプを表示します。

.EXAMPLE
    .\Start-RemoteDemucs.ps1
    スクリプトを実行すると、自動的に処理が開始される。
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

# ----- 設定項目 -----

# SSH接続先ホスト名 (ssh configで設定した名前じゃ)
$sshHost = "2s"

# Colabのdocker-compose.ymlがあるディレクトリ
$remoteDir = "/home/koa-ubuntu/Colab-docker"

# docker-compose.ymlに定義されているサービス名
# ログに 'colab-runtime-1' とあったので、おそらく 'colab-runtime' じゃろう
$serviceName = "colab-runtime"

# ブラウザで開きたいColabノートブックのURL
$colabNotebookUrl = "https://colab.research.google.com/gist/SyameimaruKoa/8b9c42bd3ddccfe8512376e8a43a7633/hybrid-demucs-music-source-separation.ipynb"

# ローカル側とリモート側でフォワーディングするポート
$port = 9000

# --------------------

try {
    Write-Host "リモートサーバー($sshHost)のColabコンテナを再起動するのじゃ..." -ForegroundColor Yellow

    # コンテナを再起動
    $sshRestartCommand = "cd $remoteDir; docker compose down; docker compose up -d"
    ssh $sshHost $sshRestartCommand

    # コンテナが完全に起動するまで少し長めに待つ
    Write-Host "コンテナの起動を待っておる... (10秒)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 10

    Write-Host "起動したコンテナから直接トークンを取得するぞ..." -ForegroundColor Yellow
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
        Write-Host "--- `jupyter server list` の実行結果 ---"
        $serverListOutput
        Write-Host "------------------------------------"
        throw "トークン取得失敗"
    }

    # クリップボードにコピー
    Set-Clipboard -Value $localUrl
    Write-Host ""
    Write-Host "接続URLをクリップボードにコピーしたぞ！" -ForegroundColor Cyan
    Write-Host $localUrl -ForegroundColor White
    Write-Host ""

    # ポートフォワーディング用のSSH接続をバックグラウンドで開始
    # -N オプションでコマンドを実行せず、ポートフォワーディングだけを維持するのじゃ
    Write-Host "SSHポートフォワーディングを開始する... (localhost:$port -> ${sshHost}:$port)" -ForegroundColor Yellow
    $sshArgs = "-N -L $($port):localhost:$($port) $sshHost"
    $sshProcess = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -PassThru -WindowStyle Hidden

    Write-Host "ポートフォワーディングが有効になったぞ。" -ForegroundColor Green
    Write-Host ""

    # 指定されたColabノートブックを開く
    Write-Host "DemucsのColabノートブックをブラウザで開くのう..." -ForegroundColor Yellow
    Start-Process $colabNotebookUrl

    Write-Host ""
    Write-Host "------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "準備完了じゃ！" -ForegroundColor Magenta
    Write-Host "ブラウザで右上の▼から「ローカルランタイムに接続」を選び、" -ForegroundColor Magenta
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