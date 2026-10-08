# GoGo To Go — 5×5=25

## 遊ぶ（Godot移行候補）

Windowsでは **[Start-5525.cmd](Start-5525.cmd)** からGodot版を起動します。既存のGodot 4.6.x、Node.js 22以上、Python 3.10以上＋Pillowを使用します。自動インストールやPC全体の設定変更はしません。起動方法・今回の検証範囲は [godot/README.md](godot/README.md)。この作業ツリーは隔離候補で、通常PCへの適用は未実施です。

従来のPython UIは **[Start-5525-Python.cmd](Start-5525-Python.cmd)** から起動できます。元ランチャーと同一バイトで、Python 3＋TkとNode.js 22以上が必要です。同じ候補のnativeルールを使うため、旧コミットへ戻す操作とは異なります。

Linuxでは `python3 native/journey_app.py`。通常の入口は、1都市・4村を往復し、報酬・経験値・キャラ別装備を持ち越して続けるキャンペーン版です。掲示板、未受注の移動、無償編成、アスタリスの宿屋（全員30GでHP/MP全回復）、下取り式の買い替え、購入前の木人試用、能力配分、ローカル進行セーブを試せます。商品・価格・道路・成長などの未定部分には試遊用の仮値を置いており、完成版の仕様確定を意味しません。

元の一件完結型は `python3 native/journey_app.py --legacy`、戦闘単体は `python3 native/app.py`。Python側のTk起動補助と既定のキャンペーン画面は保持しています。操作・必要環境は [native/README.md](native/README.md)、今回の範囲・仮仕様は [native/REPLAY.md](native/REPLAY.md)、新旧を分けた検証記録は [native/COVERAGE.md](native/COVERAGE.md)。

検証：`python native/check.py`（Windows）または `python3 native/check.py`（Linux）。結果は `native/qa-check-report.json` に出力します。Python/Tk + ローカルNodeの構成で、サーバーやネット通信は不要です。

## 元のWeb比較版を遊ぶ

**[prototype/index.html](prototype/index.html)** をブラウザーで直接開いてください。サーバー不要です。

Web版は今回のキャンペーン追加では変更していません。先行する2026-10-02の変更では編成候補に「槌戦士（仮）」を追加。スタンプは位置指定の3マス攻撃、弓のアクティブは一撃だけ射程＋1の「スナイプ」です。試し方・仮仕様は [prototype/README.md](prototype/README.md#槌戦士スタンプと弓スナイプ2026-10-02)。

- ゲームサイクル版：`prototype/index.html`
- 戦闘単体版：`prototype/battle.html`
- 仕様・検証コマンド：[prototype/README.md](prototype/README.md)

## Web比較版の動作をチェック

Node.js 22以上があれば、リポジトリ直下で `node prototype/tools/check.cjs` を実行できます。追加インストール・サーバー・ブラウザー起動は不要です。既存ルール検証、二連戦の進行、UIの配線、ローカルJSONログをまとめて確認し、失敗時は終了コード1を返します。

画面上部の「プレイログを保存（JSON）」で、そのプレイの操作・状態を保存できます。自動送信はありません。自動チェックの範囲と未検証項目は [prototype/README.md](prototype/README.md#自動チェック) を参照してください。

## フォルダ構成

```text
native/                ネイティブ・キャンペーンと旧版比較入口
Start-5525.cmd         Windows用Godot起動入口
Start-5525-Python.cmd  従来Python UIの起動入口
godot/                 Godot画面・音声・起動検出・移行検証
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

ネイティブ版の実行ファイルは `native/`、Web比較版の実行ファイルは `prototype/` にまとまっています。上記の検証コマンドはリポジトリ直下から実行できます。
