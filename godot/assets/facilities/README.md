# 施設背景の受け入れ先

素材は未到着。manifest.json が空の間は従来画面を表示する。
町広場の既存画像は変更しない。制作・承認済み原画像だけを登録する。

ファイル名: `<facility>_<style>.png`（21枚）

- facility: weapon, armor, item, accessory, guild, inn, departure_map
- style: papercut, gouache, watercolor_pen
- 推奨: 16:9 前後、背景のみ、文字なし。全体を縦横比維持で表示。

manifest の各 facility は次の形式の配列にする。

```json
{"weapon": [{"style": "papercut", "path": "res://assets/facilities/weapon_papercut.png"}]}
```

施設へ入るごとに読み取り可能な候補から専用 RNG で抽選する。
同一訪問中の再描画・購入・フィルター・人物選択・モーダル操作は保持。
施設ページを離れると終了。再訪問時の連続同一画風も許容する。
ロード・再接続・新規開始時は訪問状態を初期化する。セーブ形式は変更しない。
素材未登録・パス不在なら従来表示。試験用既存画像を完成素材として登録しない。
背景と暗色レイヤーはマウス入力を受け取らず、既存 UI を前面に配置する。
