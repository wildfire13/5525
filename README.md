# GoGo To Go — 5×5=25

## 遊ぶ
Windowsでは **[Start-5525.cmd](Start-5525.cmd)** からGodot版を起動します。Godot 4.6.x、Node.js 22以上、Python 3.10以上とPillowが必要です。Linuxではリポジトリ直下で `godot --headless --editor --path godot --import` の後に `NATIVE5525_PYTHON="$(command -v python3)" godot --path godot` を実行します。

画面・入力・音声はGodot、ゲームルールはNode.jsが担当します。Pythonは画像・保存データ・SQLiteの処理に使います。[起動設定と動作確認](godot/README.md)


## 旧Web比較版の履歴
旧Web比較版の `prototype/` は現行ツリーから整理しました。コード・画像・QA記録・同梱ライブラリとライセンスは、[削除前の固定コミット b723b4c](https://github.com/wildfire13/5525/tree/b723b4cdfb84f1b20fe895502d459092d412effb/prototype)から参照できます。当時の起動方法・仮仕様・Web検証手順は[固定版README](https://github.com/wildfire13/5525/blob/b723b4cdfb84f1b20fe895502d459092d412effb/prototype/README.md)に残しています。

現行の回帰検証は `python3 native/check.py`（Windowsは `python native/check.py`）です。旧原本の固定ハッシュ・検証コピーの由来と、現行キャンペーンの意味的検証を分けて実行します。歴史原本との追加照合手順は [native/source_tests/README.md](native/source_tests/README.md) を参照してください。


## フォルダ構成
```text
native/                Godotのルール・保存/画像処理・素材
Start-5525.cmd         Windows用Godot起動入口
godot/                 Godot画面・音声・起動検出・移行検証
HANDOFF.md             開発引き継ぎ
```

`native/` は現行Godot版の必須バックエンド・素材も含むため保持しています。上記の現行検証コマンドはリポジトリ直下から実行できます。


## ローカル環境
このフォルダの `.env.example` を `.env` にコピーし、利用する実行ファイルやフォルダを設定します。相対パスはこのフォルダが基準です。プロセス環境の指定を優先します。

`.env` の対象は `GODOT_BIN`、`NATIVE5525_NODE`、`NATIVE5525_PYTHON` です。日本語・空白を含むパスを指定でき、引用符は任意です。変数展開は行いません。空の環境変数は未指定として扱います。変更は次回起動時に読み直します。指定した実行ファイルが見つからない場合は起動を中止します。未指定の場合は既存の自動検出を使います。

通常起動は `Start-5525.cmd`、依存環境の確認は `Start-5525.cmd -Check` です。過去の検証資料にある外部証跡・作業コピーは役割名で記載しています。相対パスのコマンド例はゲームのルートから実行し、`$env:` の値は事前に設定してください。通常ランチャー以外のツールがすべて `.env` を読むわけではありません。
