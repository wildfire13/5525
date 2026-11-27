# GoGo To Go — 5×5=25

## 遊ぶ
Windowsでは **[Start-5525.cmd](Start-5525.cmd)** からGodot版を起動します。Godot 4.7.x、Node.js 22以上、Python 3.10以上とPillowが必要です。Linuxではリポジトリ直下で `godot --headless --editor --path godot --import` の後に `NATIVE5525_PYTHON="$(command -v python3)" godot --path godot` を実行します。

画面・入力・音声はGodot、ゲームルールはNode.jsが担当します。Pythonは画像・保存データ・SQLiteの処理に使います。[起動設定と動作確認](godot/README.md)


進行はクライアントの `user-data/autosave.json` 1枠に自動保存され、次回の起動時に再開します。「新しい旅」は確認後にこの枠を上書きします。save-labで作った進行を試す場合はゲームを閉じ、検証専用の保存フォルダを `NATIVE5525_USER_DATA_DIR` に指定して、その中に `autosave.json` を置いて起動します。

## 旧Web比較版の履歴
旧Web比較版の `prototype/` は現行ツリーから整理しました。コード・画像・QA記録・同梱ライブラリとライセンスは、[削除前の固定コミット b723b4c](https://github.com/wildfire13/5525/tree/b723b4cdfb84f1b20fe895502d459092d412effb/prototype)から参照できます。当時の起動方法・仮仕様・Web検証手順は[固定版README](https://github.com/wildfire13/5525/blob/b723b4cdfb84f1b20fe895502d459092d412effb/prototype/README.md)に残しています。

現行のゲームルールとデータ処理の回帰検証は、リポジトリ直下で `python native/check.py`（Linuxは `python3 native/check.py`）を実行します。Godot側もまとめて確認するときは `python godot/check.py --full` を使います。結果はワークスペースの `QA/現行版用/results` 以下に保存されます。単独のチェックアウトでは `--evidence` に本体の外の出力先を指定してください。


## フォルダ構成
```text
native/                Godotのルール・保存/画像処理・素材
Start-5525.cmd         Windows用Godot起動入口
godot/                 Godot画面・音声・起動検出・移行検証
HANDOFF.md             開発引き継ぎ
```

`native/` は現行Godot版の必須バックエンド・素材も含むため保持しています。上記の現行検証コマンドはリポジトリ直下から実行できます。


## ローカル環境
実行ファイルはキーごとに **共通 `.env` → 本体直下の `.env` → プロセス環境変数** の順で決まります。別の共通ファイルを使う場合は、起動前に環境変数 `AKI_SHARED_ENV_FILE` にその絶対パスを指定してください。Windowsでは未指定時に共通ファイルの既定位置を確認します。

対象は `GODOT_BIN`、`NATIVE5525_NODE`、`NATIVE5525_PYTHON` です。Godotエディタからの直接起動では子プロセス用のNode.jsとPythonを解決します。本体だけの設定は `.env.example` を `.env` にコピーし、使うキーだけコメントを外して設定してください。ファイル内の相対パスは各ファイルのあるフォルダ、プロセス環境変数の相対パスは本体直下が基準です。日本語・空白を含むパスと引用符に対応し、変数展開は行いません。設定したキーが空か無効なら起動時にエラーを表示します。どこにも登録されていないキーには従来の自動検出を使います。

通常起動は `Start-5525.cmd`、依存環境の確認は `Start-5525.cmd -Check` です。過去の検証資料にある外部証跡・作業コピーは役割名で記載しています。相対パスのコマンド例はゲームのルートから実行し、`$env:` の値は事前に設定してください。Godot・nativeの検査ランナーも同じ順序で実行ファイルを選びます。
