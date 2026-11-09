# 5525 ゲームバックエンド

Godotが子プロセスとして `bridge.cjs` を起動し、キャンペーン・戦闘ルールを利用します。Pythonは画像の正規化、ファイル入出力、SQLiteの処理に使用します。遊ぶには[ゲームの起動方法](../README.md)を参照してください。

## 検証

```sh
python check.py
```

`python3 check.py` は実行可能なルール・アダプター検証をまとめて走らせ、`qa-check-report.json` に結果を記録します。戦闘UIのルール検証とセーブ移行は専用テストでも確認します。実GUI・Windows検証は別途必要です。

## 主な構成

戦闘処理は `campaign-battle.js` に一本化しています。全員が戦闘中に敵陣へ移動でき、敵の行動は現在の盤面から即時に選択・実行します。ポーター相対の3護衛マス、最奥到達による突破勝利、ポーター戦闘不能の優先判定を適用します。装備の「侵入」は敵陣への初期配置権を付与します。

- `bridge.cjs` がGodotとの標準入出力を受け持ち、`campaign.js` が依頼・拠点・商店・成長・復元・セーブ検証を扱います。
- `campaign-battle.js` が戦闘ルールを扱います。[装備スキル](SKILLS11.md)と[動作条件](SKILLS11-CONTRACT.md)も参照できます。
- `godot_files.py` は画像・セーブファイル、`master_data.py` はマスターデータ、`debug_store.py` はデバッグ記録を扱います。

## 旧Python版の資料

当時の操作説明と構成は[廃止前のREADME](https://github.com/wildfire13/5525/blob/b11278f/native/README.md)、移行時の確認項目は [COVERAGE.md](COVERAGE.md) にあります。
