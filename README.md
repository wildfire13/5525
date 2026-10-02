# GoGo To Go — 5×5=25

## 遊ぶ

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
prototype/             プロトタイプ一式
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
