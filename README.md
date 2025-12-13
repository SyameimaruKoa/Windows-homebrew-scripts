# スクリプト集

このリポジトリは、日常タスクを自動化するためのバッチファイル (.bat)、PowerShell (.ps1)、および WSL/Linux 用シェルスクリプト (.sh) のコレクションです。命名は基本的に「カテゴリ_アクション-説明.拡張子」の形式です。

## 使い方

- 多くのスクリプトは「引数付き」または「ファイルのドラッグ&ドロップ」で実行できます。
- 使い方が不明な場合は `-h` または `--help` でヘルプが表示されます（バッチ/PowerShell/シェル対応）。
- PowerShell スクリプトは `Get-Help "<スクリプトのパス>" -Full` でも詳細を確認できます。

ヒント: PowerShell のドラッグ&ドロップ実行には `System_Utilities/ArgumentBased/Create-PowerShellShortcut.bat` でショートカット作成が便利です（ExecutionPolicy を自動調整して実行）。

## 他のリポジトリにあるバッチ or スクリプト

- [qaacファイル更新](https://gist.github.com/SyameimaruKoa/c9e6cc876d30bebf10232de5d2aab688)
- [ffmpegで動画を再エンコード](https://gist.github.com/SyameimaruKoa/635aef100c1b3f9f06b6a21c9bc60a17)

## ファイル一覧と機能（要約）

### System_Utilities

#### ルート

- `エクスプローラー再起動.bat`: Windows エクスプローラーを再起動。

#### Interactive

- `File_Open-Temp-Dir.bat`: 一時フォルダ（%TEMP%）を開く。
- `Hardware_NVIDIA-Powerlimit.bat`: NVIDIA GPU の電力制限を設定。
- `OS_Enable-gpedit.bat`: Home 版でローカルグループポリシーエディターを有効化。
- `OS_Set-Network-Profile.bat`: ネットワークの公開/非公開を切り替え。

#### ArgumentBased

- `Create-PowerShellShortcut.bat`: .ps1 をドラッグ&ドロップ実行できるショートカットを生成。
- `Download-LatestChromeDriver.ps1`: ChromeDriver の最新安定版を取得/更新（win64、`-DownloadOnly` で強制ダウンロード）。
- `File_Convert-GboardDictionary.ps1`: Gboard ↔ Google日本語入力の辞書形式を相互変換。
- `File_Create-Symlink.bat`: ファイル/フォルダのシンボリックリンク作成。
- `File_Delete-empty-folders.bat`: 配下の空フォルダを一括削除。
- `File_Distribute-and-Move.bat`: ルールに基づき各フォルダへ分配・移動。
- `File_Move-to-parent-folder.bat`: 親フォルダへファイルを移動。
- `File_NTFS-Compression.bat`: NTFS 圧縮/解凍を適用。
- `File_Open-in-order.bat`: 指定順で複数ファイルを開く。
- `File_Replace-Text.bat`: テキスト置換を一括実行。
- `File_Sort-by-month.bat`: 更新月 (yyyy-MM) ごとに仕分け。
- `OS_Run-WSL-script.bat`: WSL 上の .sh を実行（`OS_Run-WSL-script.bat <script.sh> [args...]`）。

### Mobile_and_SideLoading > Interactive

- `Device_Rakuten-Mini_boot-TWRP.bat`: Rakuten Mini を TWRP で起動。
- `Device_scrcpy-wrapper.bat`: scrcpy の対話ラッパー。
- `launch_scrcpy_RakutenMini.bat`: Rakuten Mini用にSSH経由でロック解除しつつscrcpyを起動。
- `Sideload_Download-SideStore.bat`: SideStore の最新版を取得。
- `Sideload_Start-AltServer.bat`: AltServer 起動と準備。

### Networking

#### Interactive
- `Remote_Reconnect-Demucs.ps1`: リモートの Demucs 接続を再接続。
- `Remote_Start-Demucs.ps1`: リモートで Demucs を起動しトンネル/転送を設定。
- `Tailscale_Ping-Loop.ps1`: Tailscale デバイスへ継続 ping。
- `Tailscale_Status-Loop.ps1`: Tailscale ステータスを定期表示（残像除去・整形表示）。
- `WiFi_Get-Info.ps1`: 現在の Wi-Fi 接続情報を表示。

#### Automation
- `Set-NetworkConfig.ps1`: ネットワーク設定の適用/変更（ルートから移設）。

### FFmpeg_and_Media > ArgumentBased

注: これらはドラッグ&ドロップ対応が中心です。詳細は各スクリプトの `--help` 参照。

#### 音声抽出 (Audio_Extraction)

- `Audio_Extraction_7.1ch-separate.bat`: 7.1ch の各チャンネルを個別に分離。
- `Audio_Extraction_Universal.bat`: 入力に応じた汎用的な音声抽出。

#### 音声変換 (Audio_Convert)

- `Audio_Convert_7.1ch-downmix.bat`: 7.1ch → ステレオにダウンミックス。
- `Audio_Convert_mix.bat`: 複数の音源をミックス。
- `Audio_Convert_to-AAC.bat`: AAC に変換。
- `Audio_Convert_to-AAC-parallel.bat`: AAC へ並列変換。
- `Audio_Convert_to-aac-folder-parallel.bat`: フォルダ内を AAC へ並列変換。
- `Audio_Convert_to-FLAC.bat`: FLAC に変換。
- `Audio_Convert_to-MP3.bat`: MP3 に変換。
- `Audio_Convert_to-OPUS.bat`: Opus に変換。
- `Audio_Convert_to-WAV.bat`: WAV に変換。

#### 動画変換 (Video_Convert)

- `Video_Convert_concat.bat`: 複数動画を結合。
- `Video_Convert_from-still-image-and-audio.bat`: 静止画+音声から動画生成。
- `Video_Convert_lossless.bat`: 無劣化で別コンテナへ移行（session.mpd の自動処理モード対応※Steamバックグラウンド録画変換用）
- `Video_Convert_merge-video-and-audio.bat`: 動画と音声を結合。
- `Video_Convert_to-images.ps1`: 動画 → 連番画像に変換。

#### 画像処理 (Image)

- `Image_Upscale_waifu2x.bat`: waifu2x でアップスケール。

#### シェル（WSL/Linux）

- `Shell/Image_Convert_screenshot.sh`: スクリーンショット形式の変換（WSL 向け、シェル用へ移設）。

#### メディア操作・情報 (Media_Action / Media_Info)

- `Media_Action_copy-metadata.bat`: 音声メタデータ/アートワークのコピー。
- `Media_Action_play.bat`: ffplay で再生。
- `Media_Action_play-waveform.bat`: 波形表示しながら再生。
- `Media_Info_get-info.ps1`: メディア情報の取得。

#### 関連ツール (Tool)

- `Tool_Fix_timebase-framerate.ps1`: タイムベースとフレームレートの不整合を補正。
- `Tool_tsMuxeR.bat`: tsMuxeR による M2TS/TS の操作。
- `Tool_tsMuxeR_subtitle-multi-audio.bat`: tsMuxeR で字幕/多重音声を扱う。
- `Tool_upconv_copy-properties.bat`: アップコンバート後にタグ/アートワークを移植。

## 依存関係（代表例）

- FFmpeg/FFprobe（多くのメディア系スクリプト）
- tsMuxeR（TS/M2TS 関連）
- waifu2x の実行環境（画像アップスケール）
- scrcpy（Android ミラーリング）
- AltServer/SideStore（サイドロード関連）
- Tailscale CLI、Demucs（ネットワーク/音源分離関連）

各スクリプトは存在チェックやパス設定を同梱している場合があります。詳細は `--help` を参照してください。

## ヘルプの見方

各スクリプトは、引数 `-h` または `--help` で詳しい使い方を表示できます。

### バッチファイルの場合

```cmd
C:\> script_name.bat --help
```

### PowerShell スクリプトの場合

```powershell
PS C:\> Get-Help .\script_name.ps1 -Full
```
