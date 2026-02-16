# スクリプト集

日常タスクを自動化するバッチファイル (.bat)、PowerShell (.ps1)、シェルスクリプト (.sh) のコレクションです。

## 使い方

- 多くのスクリプトは「引数付き」または「ファイルのドラッグ&ドロップ」で実行できます。
- `-h` または `--help` でヘルプを表示（バッチ/PowerShell/シェル対応）。
- PowerShell スクリプトは `Get-Help "<スクリプトのパス>" -Full` でも詳細を確認できます。

> **ヒント:** PowerShell のドラッグ&ドロップ実行には [Create-PowerShellShortcut.bat](System/Create-PowerShellShortcut.bat) でショートカット作成が便利です。

## 他のリポジトリにあるバッチ or スクリプト

- [qaacファイル更新](https://gist.github.com/SyameimaruKoa/c9e6cc876d30bebf10232de5d2aab688)
- [ffmpegで動画を再エンコード](https://gist.github.com/SyameimaruKoa/635aef100c1b3f9f06b6a21c9bc60a17)

## フォルダ構成

```
Media/          メディア変換・処理
    Audio/          音声変換・抽出
    Video/          動画変換
    Image/          画像変換・アップスケール
    Playback/       再生・情報取得
    Tools/          メディア関連ツール（メタデータ、tsMuxeR 等）
File/           ファイル操作（圧縮、移動、仕分け、変換 等）
System/         OS・ハードウェア・開発ツール
Network/        ネットワーク関連（Tailscale、Wi-Fi、リモート接続）
Mobile/         Android・サイドロード
```

## ファイル一覧

### Media/Audio — 音声変換・抽出

| ファイル                                                                                         | 説明                                      |
| ------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| [Audio_Convert_7.1ch-downmix.bat](Media/Audio/Audio_Convert_7.1ch-downmix.bat)                   | 7.1ch → ステレオにダウンミックス          |
| [Audio_Convert_mix.bat](Media/Audio/Audio_Convert_mix.bat)                                       | 複数の音源をミックス                      |
| [Audio_Convert_to-AAC.bat](Media/Audio/Audio_Convert_to-AAC.bat)                                 | AAC に変換（qaac64 使用）                 |
| [Audio_Convert_to-AAC-parallel.bat](Media/Audio/Audio_Convert_to-AAC-parallel.bat)               | AAC へ並列変換（ワーカー）                |
| [Audio_Convert_to-aac-folder-parallel.bat](Media/Audio/Audio_Convert_to-aac-folder-parallel.bat) | フォルダ内を AAC へ並列変換（ランチャー） |
| [Audio_Convert_to-FLAC.bat](Media/Audio/Audio_Convert_to-FLAC.bat)                               | FLAC に変換                               |
| [Audio_Convert_to-MP3.bat](Media/Audio/Audio_Convert_to-MP3.bat)                                 | MP3 に変換                                |
| [Audio_Convert_to-OPUS.bat](Media/Audio/Audio_Convert_to-OPUS.bat)                               | Opus に変換                               |
| [Audio_Convert_to-WAV.bat](Media/Audio/Audio_Convert_to-WAV.bat)                                 | WAV に変換                                |
| [Audio_Extraction_7.1ch-separate.bat](Media/Audio/Audio_Extraction_7.1ch-separate.bat)           | 7.1ch の各チャンネルを個別に分離          |
| [Audio_Extraction_Universal.bat](Media/Audio/Audio_Extraction_Universal.bat)                     | 入力に応じた汎用的な音声抽出              |

### Media/Video — 動画変換

| ファイル                                                                                                 | 説明                                                 |
| -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| [Video_Convert_concat.bat](Media/Video/Video_Convert_concat.bat)                                         | 複数動画を結合（チャプター自動生成）                 |
| [Video_Convert_from-still-image-and-audio.bat](Media/Video/Video_Convert_from-still-image-and-audio.bat) | 静止画+音声から動画生成                              |
| [Video_Convert_lossless.bat](Media/Video/Video_Convert_lossless.bat)                                     | 無劣化で別コンテナへ移行（session.mpd 自動処理対応） |
| [Video_Convert_merge-video-and-audio.bat](Media/Video/Video_Convert_merge-video-and-audio.bat)           | 動画と音声を結合                                     |
| [Video_Convert_to-images.ps1](Media/Video/Video_Convert_to-images.ps1)                                   | 動画 → 連番画像に変換                                |

### Media/Image — 画像処理

| ファイル                                                               | 説明                                |
| ---------------------------------------------------------------------- | ----------------------------------- |
| [Image_Upscale_waifu2x.bat](Media/Image/Image_Upscale_waifu2x.bat)     | waifu2x でアップスケール            |
| [Image_Convert_screenshot.sh](Media/Image/Image_Convert_screenshot.sh) | PNG→WebP 一括変換（WSL/Linux 向け） |

### Media/Playback — 再生・情報取得

| ファイル                                                                        | 説明                               |
| ------------------------------------------------------------------------------- | ---------------------------------- |
| [Media_Action_play.bat](Media/Playback/Media_Action_play.bat)                   | ffplay で再生（フィルター入力可）  |
| [Media_Action_play-waveform.bat](Media/Playback/Media_Action_play-waveform.bat) | 波形表示しながら再生 (WS151使用)   |
| [Media_Info_get-info.ps1](Media/Playback/Media_Info_get-info.ps1)               | メディア情報の取得（VFR 検知付き） |

### Media/Tools — メディア関連ツール

| ファイル                                                                                   | 説明                                        |
| ------------------------------------------------------------------------------------------ | ------------------------------------------- |
| [Media_Action_copy-metadata.bat](Media/Tools/Media_Action_copy-metadata.bat)               | 音声メタデータ/アートワークのコピー         |
| [mkv_stats_fixer.bat](Media/Tools/mkv_stats_fixer.bat)                                     | MKV/WebM の統計情報タグを一括追加・更新     |
| [Tool_Fix_timebase-framerate.ps1](Media/Tools/Tool_Fix_timebase-framerate.ps1)             | タイムベースとフレームレートの不整合を補正  |
| [Tool_tsMuxeR.bat](Media/Tools/Tool_tsMuxeR.bat)                                           | tsMuxeR による M2TS/TS の操作               |
| [Tool_tsMuxeR_subtitle-multi-audio.bat](Media/Tools/Tool_tsMuxeR_subtitle-multi-audio.bat) | tsMuxeR で字幕/多重音声を扱う               |
| [Tool_upconv_copy-properties.bat](Media/Tools/Tool_upconv_copy-properties.bat)             | アップコンバート後にタグ/アートワークを移植 |

### File — ファイル操作

| ファイル                                                                    | 説明                                          |
| --------------------------------------------------------------------------- | --------------------------------------------- |
| [File_Convert-GboardDictionary.ps1](File/File_Convert-GboardDictionary.ps1) | Gboard ↔ Google日本語入力の辞書形式を相互変換 |
| [File_Create-Symlink.bat](File/File_Create-Symlink.bat)                     | ファイル/フォルダのシンボリックリンク作成     |
| [File_Delete-empty-folders.bat](File/File_Delete-empty-folders.bat)         | 配下の空フォルダを一括削除                    |
| [File_Distribute-and-Move.bat](File/File_Distribute-and-Move.bat)           | ルールに基づき各フォルダへ分配・移動          |
| [File_Move-to-parent-folder.bat](File/File_Move-to-parent-folder.bat)       | 親フォルダへファイルを移動                    |
| [File_NTFS-Compression.bat](File/File_NTFS-Compression.bat)                 | NTFS 圧縮/解凍を適用                          |
| [File_Open-in-order.bat](File/File_Open-in-order.bat)                       | 指定順で複数ファイルを開く                    |
| [File_Open-Temp-Dir.bat](File/File_Open-Temp-Dir.bat)                       | 一時フォルダ（%TEMP%）を開く                  |
| [File_Replace-Text.bat](File/File_Replace-Text.bat)                         | テキスト置換を一括実行                        |
| [File_Sort-by-month.bat](File/File_Sort-by-month.bat)                       | 更新月 (yyyy-MM) ごとに仕分け                 |

### System — OS・ハードウェア・開発ツール

| ファイル                                                                  | 説明                                        |
| ------------------------------------------------------------------------- | ------------------------------------------- |
| [Create-PowerShellShortcut.bat](System/Create-PowerShellShortcut.bat)     | .ps1 の D&D 実行ショートカットを生成        |
| [Download-LatestChromeDriver.ps1](System/Download-LatestChromeDriver.ps1) | ChromeDriver 最新安定版を取得/更新          |
| [Hardware_NVIDIA-Powerlimit.bat](System/Hardware_NVIDIA-Powerlimit.bat)   | NVIDIA GPU の電力制限を設定                 |
| [OS_Enable-gpedit.bat](System/OS_Enable-gpedit.bat)                       | Home 版でグループポリシーエディターを有効化 |
| [OS_Run-WSL-script.bat](System/OS_Run-WSL-script.bat)                     | WSL 上の .sh を実行                         |
| [Tool_Compress-with-UPX.ps1](System/Tool_Compress-with-UPX.ps1)           | UPX で .exe を圧縮（バックアップ自動作成）  |
| [エクスプローラー再起動.bat](System/エクスプローラー再起動.bat)           | Windows エクスプローラーを再起動            |

### Network — ネットワーク関連

| ファイル                                                           | 説明                                          |
| ------------------------------------------------------------------ | --------------------------------------------- |
| [Remote_Reconnect-Demucs.ps1](Network/Remote_Reconnect-Demucs.ps1) | リモートの Demucs 接続を再接続                |
| [Remote_Start-Demucs.ps1](Network/Remote_Start-Demucs.ps1)         | リモートで Demucs を起動しトンネル/転送を設定 |
| [Set-NetworkConfig.ps1](Network/Set-NetworkConfig.ps1)             | ネットワーク設定の適用/変更（GUI）            |
| [Tailscale_Ping-Loop.ps1](Network/Tailscale_Ping-Loop.ps1)         | Tailscale デバイスへ継続 ping                 |
| [Tailscale_Status-Loop.ps1](Network/Tailscale_Status-Loop.ps1)     | Tailscale ステータスを定期表示（残像除去）    |
| [WiFi_Get-Info.ps1](Network/WiFi_Get-Info.ps1)                     | 現在の Wi-Fi 接続情報を表示                   |

### Mobile — Android・サイドロード

| ファイル                                                                      | 説明                                                       |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------- |
| [Device_Rakuten-Mini_boot-TWRP.bat](Mobile/Device_Rakuten-Mini_boot-TWRP.bat) | Rakuten Mini を TWRP で起動                                |
| [Device_scrcpy-wrapper.bat](Mobile/Device_scrcpy-wrapper.bat)                 | scrcpy の対話ラッパー                                      |
| [launch_scrcpy_RakutenMini.bat](Mobile/launch_scrcpy_RakutenMini.bat)         | Rakuten Mini 用に SSH 経由でロック解除しつつ scrcpy を起動 |
| [Sideload_Download-SideStore.bat](Mobile/Sideload_Download-SideStore.bat)     | SideStore の最新版を取得                                   |
| [Sideload_Start-AltServer.bat](Mobile/Sideload_Start-AltServer.bat)           | AltServer 起動と準備                                       |

## 依存関係（代表例）

| ツール                | 用途                       |
| --------------------- | -------------------------- |
| FFmpeg / FFprobe      | 多くのメディア系スクリプト |
| qaac64                | AAC 変換                   |
| tsMuxeR               | TS/M2TS 関連               |
| waifu2x               | 画像アップスケール         |
| scrcpy / ADB          | Android ミラーリング       |
| AltServer / SideStore | サイドロード関連           |
| Tailscale CLI         | VPN ネットワーク関連       |
| Demucs                | 音源分離                   |

各スクリプトは存在チェックやパス設定を同梱している場合があります。詳細は `--help` を参照してください。

## ヘルプの見方

```cmd
C:\> script_name.bat --help
```

```powershell
PS C:\> Get-Help .\script_name.ps1 -Full
```
