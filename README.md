# GoGo To Go — 5×5=25

## 戦術依頼「水門の鐘」

アスタリスの掲示板で「水門の鐘」を受け、荷物をポーターに預けてください。ギルドで同行者を選び、街道口からイースへ。巻上機に守護者を移動させ、その場を守れば、ポーターが水門から突破できます。峠を急ぐか、川沿いで舟守を拾うかは最初の分かれ道で決まります。開門後、味方が通路の敵を倒すなどしてポーターが出口へ一手で届くようになると、一戦に一度だけ「舟守の合図」でポーターの手番が繰り上がります。野営と第二区間を経て、イースの掲示板で荷物を引き渡します。

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

## GitHub Actions

Linuxの起動・現行UI回帰とWindowsのCMD／PowerShellランチャーチェックを、標準のGitHub-hosted runnerで実行します。Godot 4.6.3の公式配布とSHA-256、Node.js 24、Python 3.12、Pillow 12.3.0を使用します。GUIの見た目・実機の音声は別途確認が必要です。旧仕様テストを含む `godot/check.py --full` は必須化していません。

初回の手動実行で両方の成功を確認済みです。LinuxはGodot・nativeのコード／アセットとCI設定、Windowsはランチャー・起動に使うコード／アセットと専用テスト・CI設定のmainへのpushで実行します。Markdownのみの変更は対象外です。Actionsタブの各ワークフローの `Run workflow` から手動実行もできます。テストは隔離プロファイルを使い、artifactは合成テストの要約のみ5日保持します。Actionsの実行ログ保持期間はワークフローYAMLでは指定できないため、リポジトリの Settings → Actions → General で5日への設定が必要です。個人のセーブ・環境変数一覧・資格情報は出力やアップロードの対象にしません。
