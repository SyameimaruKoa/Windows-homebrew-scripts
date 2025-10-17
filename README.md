# スクリプト集

このリポジトリは、日常的なタスクを自動化するためのバッチファイルとPowerShellスクリプトのコレクションです。

## 使い方

多くのスクリプトは、コマンドプロンプトやPowerShellで引数を指定して実行するか、ファイルを直接ドラッグアンドドロップすることで動作します。
各スクリプトのファイル名がその機能を表しています (`カテゴリ_アクション-説明.拡張子`)。

- 引数が必要なスクリプト（主に`ArgumentBased`フォルダ内）の使い方がわからない場合は、`-h`または`--help`引数を付けて実行すると、ヘルプが表示されます。
- PowerShellスクリプト（`.ps1`）の場合は、`Get-Help "スクリプトのパス" -Full`で詳細なヘルプを参照できます。

### PowerShellスクリプトのドラッグアンドドロップ実行について

PowerShellスクリプト（`.ps1`）をドラッグアンドドロップで手軽に実行するために、専用のショートカットを作成すると便利です。
Windowsのセキュリティ設定により、直接のドラッグアンドドロップが機能しない場合でも、この方法で実行できます。

1. デスクトップなどの好きな場所で右クリックし、**[新規作成] > [ショートカット]** を選択します。
2. 「項目の場所を入力してください」という画面で、以下のように入力します。

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\your\script.ps1"
   ```

   ※ `"C:\path\to\your\script.ps1"` の部分は、実行したいスクリプトの**絶対パス**に書き換えてください。
3. 「次へ」をクリックし、ショートカットに分かりやすい名前（例：「動画を画像に変換」など）を付け、「完了」をクリックします。
4. 作成されたショートカットにファイル（動画ファイルなど）をドラッグアンドドロップすると、スクリプトが実行されます。

## ファイル一覧と機能

### System_Utilities

#### Interactive (System_Utilities)

- **`Hardware_NVIDIA-Powerlimit.bat`**: NVIDIA GPUの電力制限を設定します。
- **`エクスプローラー再起動.bat`**: Windowsエクスプローラーを再起動します。
- **`OS_Set-Network-Profile.bat`**: ネットワーク接続のカテゴリ（パブリック/プライベート）を変更します。
- **`OS_Enable-gpedit.bat`**: Windows Home Editionでローカルグループポリシーエディターを有効にします。
- **`File_Open-Temp-Dir.bat`**: 一時フォルダ（TEMP）を開きます。
- **`File_Open-Default-Temp-Dir.bat`**: デフォルトの一時フォルダを開きます。

#### ArgumentBased (System_Utilities)

- **`File_NTFS-Compression.bat`**: ファイルやフォルダのNTFS圧縮/解凍を行います。
- **`OS_Run-WSL-script.bat`**: WSL上のシェルスクリプトを実行します。使い方: `OS_Run-WSL-script.bat <script.sh> [args...]`。
- **`File_Create-Symlink.bat`**: ファイルやフォルダのシンボリックリンクを作成します。
- **`File_Replace-Text.bat`**: テキストファイル内の文字列を置換します。
- **`File_Open-in-order.bat`**: 複数のファイルを指定した順番で開きます。
- **`File_Distribute-and-Move.bat`**: ファイルをルールに基づいて各フォルダに分配・移動します。
- **`File_Sort-by-month.bat`**: ファイルを更新月(yyyy-MM)ごとにフォルダ分けします（直下のファイルのみ）。
- **`File_Delete-empty-folders.bat`**: 指定したフォルダ以下の空フォルダをすべて削除します。
- **`File_Move-to-parent-folder.bat`**: ファイルを一つ上の階層（親フォルダ）に移動します。
- **`File_Convert-GboardDictionary.ps1`**: GboardとGoogle日本語入力のユーザー辞書ファイル形式を相互に変換します。

### Mobile_and_SideLoading

#### Interactive (Mobile_and_SideLoading)

- **`Sideload_Start-AltServer.bat`**: AltServerを起動し、SideStoreのダウンロード準備をします。
- **`Device_Rakuten-Mini_boot-TWRP.bat`**: Rakuten MiniをTWRPで起動します。
- **`Device_scrcpy-wrapper.bat`**: `scrcpy` を対話形式で簡単に利用できます。
- **`Sideload_Download-SideStore.bat`**: SideStoreの最新版をダウンロードします。

### Networking

#### Interactive (Networking)

- **`Remote_Start-Demucs.ps1`**: リモートサーバー上のDemucsの起動とポートフォワーディングを自動化します。
- **`Tailscale_Ping-Loop.ps1`**: Tailscaleデバイスに継続的にpingを送信します。
- **`Tailscale_Status-Loop.ps1`**: Tailscaleのステータスを定期的に表示します。
- **`WiFi_Get-Info.ps1`**: 現在のWi-Fi接続情報を定期的に表示します。

### FFmpeg_and_Media

#### ArgumentBased (FFmpeg_and_Media)

このカテゴリのスクリプトは、主にドラッグアンドドロップでの使用を想定しています。

##### 音声抽出 (Audio_Extraction)

- **`Audio_Extraction_2nd-audio.bat`**: 動画ファイルの2番目の音声トラックを抽出します。
- **`Audio_Extraction_flac.bat`**: FLAC音声トラックを抽出します。
- **`Audio_Extraction_m4a.bat`**: M4A音声トラックを抽出します。
- **`Audio_Extraction_mp3.bat`**: MP3音声トラックを抽出します。
- **`Audio_Extraction_opus.bat`**: Opus音声トラックを抽出します。
- **`Audio_Extraction_wav.bat`**: WAV音声トラックを抽出します。
- **`Audio_Extraction_7.1ch-separate.bat`**: 7.1ch音声の各チャンネルを個別のファイルに分離します。
- **`Audio_Extraction_multi-track.bat`**: 動画から複数の音声トラックを分離します。

##### 音声変換 (Audio_Convert)

- **`Audio_Convert_7.1ch-downmix.bat`**: 7.1ch音声をステレオにダウンミックスします。
- **`Audio_Convert_to-aac.bat`**: AAC形式に変換します。
- **`Audio_Convert_to-aac-parallel.bat`**: AAC形式に並列変換します。
- **`Audio_Convert_to-aac-folder-parallel.bat`**: フォルダ内のファイルをAAC形式に並列変換します。
- **`Audio_Convert_to-flac.bat`**: 各種メディアからFLACへ変換します。
- **`Audio_Convert_to-mp3.bat`**: MP3形式に変換します。
- **`Audio_Convert_to-opus.bat`**: Opus形式に変換します。
- **`Audio_Convert_to-wav.bat`**: WAV形式に変換します。
- **`Audio_Convert_mix.bat`**: 複数の音楽ファイルをミックスします。

##### 動画変換 (Video_Convert)

- **`Video_Convert_to-images.ps1`**: 動画を連番画像に変換します。
- **`Video_Convert_concat.bat`**: 複数の動画ファイルを結合します。
- **`Video_Convert_lossless.bat`**: 動画を無劣化で別のコンテナ形式に変換します。
- **`Video_Convert_from-still-image-and-audio.bat`**: 音楽ファイルと静止画から動画を作成します。
- **`Video_Convert_merge-video-and-audio.bat`**: 動画ファイルと音声ファイルを結合します。

##### 画像処理 (Image)

- **`Image_Convert_to-webp.bat`**: 画像ファイルをWebP形式に変換します。
- **`Image_Upscale_waifu2x.bat`**: `waifu2x`を使用して画像をアップスケーリングします。
- **`Image_Convert_screenshot.sh`**: スクリーンショットの形式を変換します（WSL環境向け）。

##### メディア操作・情報 (Media_Action, Media_Info)

- **`Media_Info_get-info.bat` / `.ps1`**: メディアファイルの情報を表示します。
- **`Media_Action_play.bat`**: `ffplay`でメディアファイルを再生します。
- **`Media_Action_play-waveform.bat`**: 音声ファイルの波形を表示しながら再生します。
- **`Media_Action_copy-metadata.bat`**: 音楽ファイルのメタデータをコピーします。

##### 関連ツール (Tool)

- **`Tool_Fix_timebase-framerate.ps1`**: 動画のタイムベースとフレームレートの不整合を修正します。
- **`Tool_tsMuxeR.bat`**: `tsMuxeR`を使用してMPEG-TSコンテナを操作します。
- **`Tool_tsMuxeR_subtitle-multi-audio.bat`**: `tsMuxeR`で字幕と多重音声を扱います。
- **`Tool_upconv_copy-properties.bat`**: 音声ファイルのメタデータやジャケット画像を抽出し、アップコンバート後の出力（FLAC/WAV/AAC）へコピーします。

## ヘルプの見方

各スクリプトは、引数 `-h` または `--help` を付けて実行することで、詳しい使い方（ヘルプ）が表示されます。

### バッチファイルの場合

```cmd
C:\> script_name.bat --help
```

### PowerShellスクリプトの場合

```powershell
PS C:\> Get-Help .\script_name.ps1 -Full
```
