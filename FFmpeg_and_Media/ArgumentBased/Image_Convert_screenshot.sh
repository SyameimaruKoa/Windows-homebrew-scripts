#!/bin/bash

# ImageMagickの`convert`コマンドがあるか確認
if ! command -v convert &> /dev/null; then
    echo "ImageMagickがインストールされていないのじゃ。sudo apt install imagemagick で入れるのじゃ。"
    exit 1
fi

# スクリプトがあるディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo 実行場所：$SCRIPT_DIR

# PNGファイルのリストを取得
files=("$SCRIPT_DIR"/*.png)
total_files=${#files[@]}

# 対象ファイルがない場合は終了
if [ "$total_files" -eq 0 ]; then
    echo "PNGファイルが見つからんのじゃ。"
    exit 0
fi

# 進捗用のカウンター
count=0

# スクリプトがあるディレクトリ内のPNGファイルを処理
for file in "${files[@]}"; do
    [ -e "$file" ] || continue

    # ファイル名のみを取得
    filename="${file##*/}"

    # 元ファイルのタイムスタンプを取得
    mod_time=$(stat -c %y "$file")

    # WebPに変換
    convert "$file" -quality 90 "$SCRIPT_DIR/${filename%.png}.webp"

    # 変換成功したら元のPNGを削除
    if [ -e "$SCRIPT_DIR/${filename%.png}.webp" ]; then
        rm "$file"
        
        # タイムスタンプを元のファイルと同じに設定
        touch -d "$mod_time" "$SCRIPT_DIR/${filename%.png}.webp"

        # 進捗カウント更新
        count=$((count + 1))
        progress=$((count * 100 / total_files))

        echo "[$count/$total_files] 変換完了: $filename -> ${filename%.png}.webp ($progress%)"
    else
        echo "変換失敗: $filename"
    fi
done

echo "すべての処理が完了したのじゃ！"
