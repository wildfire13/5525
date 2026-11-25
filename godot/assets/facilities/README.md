# 施設背景の受け入れ先

6施設の背景6枚を manifest.json に登録済み（すべて原本バイトのまま）。

- 差替済み6施設（`weapon`, `armor`, `item`, `accessory`, `guild`, `inn`）:
  - ファイル名:
    - `bg_guild_interior.png` (`guild`)
    - `bg_inn_interior.png` (`inn`)
    - `bg_weapon_shop_interior.png` (`weapon`)
    - `bg_armor_shop_interior.png` (`armor`)
    - `bg_item_shop_interior.png` (`item`)
    - `bg_accessory_shop_interior.png` (`accessory`)
  - style: `interior`（各1枚・計6枚）
  - 解像度: `1920×1080`。

出発マップは現在地の町・村と同じ背景を表示する。

manifest/CSV/SHA一覧との照合とPNG読込みを確認済み。
制作・承認済み原画像だけを登録する。

- 推奨: 16:9 前後、背景のみ、文字なし。全体を縦横比維持で表示。

manifest の各 facility は次の形式の配列にする。

```json
{"weapon": [{"style": "interior", "path": "res://assets/facilities/bg_weapon_shop_interior.png"}]}
```

施設へ入るごとに読み取り可能な候補から専用 RNG で抽選する。
同一訪問中の再描画・購入・フィルター・人物選択・モーダル操作は保持。
施設ページを離れると終了。再訪問時の連続同一画風も許容する。
ロード・新規開始時は訪問状態を初期化する。セーブ形式は変更しない。
素材未登録・パス不在なら従来表示。試験用既存画像を完成素材として登録しない。
背景と暗色レイヤーはマウス入力を受け取らず、既存 UI を前面に配置する。
