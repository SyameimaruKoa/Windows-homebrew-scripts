# 実装履歴

## 2026-03-18

### Media/Video/Video_Convert_lossless.bat
- 出力拡張子の選択肢に `webm` を追加。
- 音声処理の選択肢に「FLACに変換してMKVで出力」を追加。
  - FLAC選択時、拡張子が `mkv` 以外なら自動で `mkv` に変更。
- 出力先選択を追加。
  - 入力ファイルと同じフォルダ
  - `%USERPROFILE%\Downloads`
- `session.mpd` 固定モード時の既定値として `_output_destination=input` を追加（既存挙動維持）。
- ヘルプ表示を新仕様に合わせて更新。
