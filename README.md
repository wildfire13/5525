# GoGo To Go — 5×5=25

## 遊ぶ（Godot移行候補）

Windowsでは **[Start-5525.cmd](Start-5525.cmd)** からGodot版を起動します。既存のGodot 4.6.x、Node.js 22以上、Python 3.10以上＋Pillowを使用します。自動インストールやPC全体の設定変更はしません。起動方法・今回の検証範囲は [godot/README.md](godot/README.md)。この作業ツリーは隔離候補で、通常PCへの適用は未実施です。

従来のPython UIは **[Start-5525-Python.cmd](Start-5525-Python.cmd)** から起動できます。元ランチャーと同一バイトで、Python 3＋TkとNode.js 22以上が必要です。同じ候補のnativeルールを使うため、旧コミットへ戻す操作とは異なります。

Linuxでは `python3 native/journey_app.py`。通常の入口は、1都市・4村を往復し、報酬・経験値・キャラ別装備を持ち越して続けるキャンペーン版です。掲示板、未受注の移動、無償編成、アスタリスの宿屋（全員30GでHP/MP全回復）、下取り式の買い替え、購入前の木人試用、能力配分、ローカル進行セーブを試せます。商品・価格・道路・成長などの未定部分には試遊用の仮値を置いており、完成版の仕様確定を意味しません。

元の一件完結型は `python3 native/journey_app.py --legacy`、戦闘単体は `python3 native/app.py`。Python側のTk起動補助と既定のキャンペーン画面は保持しています。操作・必要環境は [native/README.md](native/README.md)、今回の範囲・仮仕様は [native/REPLAY.md](native/REPLAY.md)、新旧を分けた検証記録は [native/COVERAGE.md](native/COVERAGE.md)。

検証：`python native/check.py`（Windows）または `python3 native/check.py`（Linux）。結果は `native/qa-check-report.json` に出力します。Python/Tk + ローカルNodeの構成で、サーバーやネット通信は不要です。

## 旧Web比較版の履歴

旧Web比較版の `prototype/` は現行ツリーから整理しました。コード・画像・QA記録・同梱ライブラリとライセンスは、[削除前の固定コミット b723b4c](https://github.com/wildfire13/5525/tree/b723b4cdfb84f1b20fe895502d459092d412effb/prototype)から参照できます。当時の起動方法・仮仕様・Web検証手順は[固定版README](https://github.com/wildfire13/5525/blob/b723b4cdfb84f1b20fe895502d459092d412effb/prototype/README.md)に残しています。

現行の回帰検証は `python3 native/check.py`（Windowsは `python native/check.py`）です。旧原本の固定ハッシュ・検証コピーの由来と、現行キャンペーンの意味的検証を分けて実行します。歴史原本との追加照合手順は [native/source_tests/README.md](native/source_tests/README.md) を参照してください。

## フォルダ構成

```text
native/                Godotのルール・保存/画像処理・素材とPython比較UI
Start-5525.cmd         Windows用Godot起動入口
Start-5525-Python.cmd  従来Python UIの起動入口
godot/                 Godot画面・音声・起動検出・移行検証
HANDOFF.md             開発引き継ぎ
```

`native/` は現行Godot版の必須バックエンド・素材も含むため保持しています。上記の現行検証コマンドはリポジトリ直下から実行できます。

## GitHub Actions

Linuxの起動・現行UI回帰とWindowsのCMD／PowerShellランチャーチェックを、標準のGitHub-hosted runnerで実行します。Godot 4.6.3の公式配布とSHA-256、Node.js 24、Python 3.12、Pillow 12.3.0を使用します。GUIの見た目・実機の音声は別途確認が必要です。旧仕様テストを含む `godot/check.py --full` は必須化していません。

初回の手動実行で両方の成功を確認済みです。LinuxはGodot・nativeのコード／アセットとCI設定、Windowsはランチャー・起動に使うコード／アセットと専用テスト・CI設定のmainへのpushで実行します。Markdownのみの変更は対象外です。Actionsタブの各ワークフローの `Run workflow` から手動実行もできます。テストは隔離プロファイルを使い、artifactは合成テストの要約のみ5日保持します。Actionsの実行ログ保持期間はワークフローYAMLでは指定できないため、リポジトリの Settings → Actions → General で5日への設定が必要です。個人のセーブ・環境変数一覧・資格情報は出力やアップロードの対象にしません。
