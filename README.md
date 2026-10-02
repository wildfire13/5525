# GoGo To Go — 5×5=25

## 遊ぶ（正式プロトタイプ：ネイティブ版）

Windowsでは **[Start-5525.cmd](Start-5525.cmd)** をダブルクリックしてください。既存のPython 3 + TkとNode.jsが必要です。ランチャーは不足を表示するだけで、インストールや設定変更はしません。

Linuxでは `python3 native/journey_app.py`。戦闘単体版は画面右上のボタン、または `python3 native/app.py`。旅程・編成・配置・二連戦・休息・配達・報酬・再挑戦をネイティブ画面でテストできます。操作、必要環境、2D表示などの違いは [native/README.md](native/README.md)、検証の内訳は [native/COVERAGE.md](native/COVERAGE.md)。

検証：`python native/check.py`（Windows）または `python3 native/check.py`（Linux）。結果は `native/qa-check-report.json` に出力します。Python/Tk + ローカルNodeの構成で、サーバーやネット通信は不要です。

## Web比較版を遊ぶ

**[prototype/index.html](prototype/index.html)** をブラウザーで直接開いてください。サーバー不要です。

2026-10-02：編成候補に「槌戦士（仮）」を追加。スタンプは位置指定の3マス攻撃、弓のアクティブは一撃だけ射程＋1の「スナイプ」になりました。試し方・仮仕様は [prototype/README.md](prototype/README.md#槌戦士スタンプと弓スナイプ2026-10-02)。

- ゲームサイクル版：`prototype/index.html`
- 戦闘単体版：`prototype/battle.html`
- 仕様・検証コマンド：[prototype/README.md](prototype/README.md)

## 動作をまとめてチェック

Node.js 22以上があれば、リポジトリ直下で `node prototype/tools/check.cjs` を実行できます。追加インストール・サーバー・ブラウザー起動は不要です。既存ルール検証、二連戦の進行、UIの配線、ローカルJSONログをまとめて確認し、失敗時は終了コード1を返します。

画面上部の「プレイログを保存（JSON）」で、そのプレイの操作・状態を保存できます。自動送信はありません。自動チェックの範囲と未検証項目は [prototype/README.md](prototype/README.md#自動チェック) を参照してください。

## フォルダ構成

```text
native/                正式ネイティブ・プロトタイプ
Start-5525.cmd         Windows用起動入口
prototype/             変更せず保持したWeb比較版
  index.html           ゲームサイクル版の入口
  battle.html          戦闘単体版の入口
  assets/characters/   仮当て画像（透過前・透過後、敵味方）
  src/                 ゲームコード
  vendor/              Three.jsとライセンス
  tools/               検証・比較プレイ用ツール
  qa/                  検証結果・スクリーンショット
FromAdmin/             企画・制作資料
FromAstra/             実装・試遊の報告
FromLuna/              Lunaの試遊記録
HANDOFF.md             開発引き継ぎ
```

実行に必要なファイルは `prototype/` 内にまとまっています。検証コマンドは `prototype/` を作業ディレクトリにして実行してください。
