# GoGo To Go — 5×5=25

## 遊ぶ

**[prototype/index.html](prototype/index.html)** をブラウザーで直接開いてください。サーバー不要です。

- ゲームサイクル版：`prototype/index.html`
- 戦闘単体版：`prototype/battle.html`
- 仕様・検証コマンド：[prototype/README.md](prototype/README.md)

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
