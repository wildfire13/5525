# 施設背景の受け入れ先

7施設の背景11枚を manifest.json に登録済み（すべて原本バイトのまま）。

- 差替済み5施設（`weapon`, `armor`, `item`, `accessory`, `guild`）:
  - ファイル名: `<facility>.png`（各1枚・計5枚）
  - style: `interior`
  - 解像度: `1920×1080`（`G:\Apps\CodexProjects\Share\prot_assets\背景\施設内` から原本バイトのまま受領）
- 既存維持2施設（`inn`, `departure_map`）:
  - ファイル名: `<facility>_<style>.png`（各3枚・計6枚）
  - style: `papercut`, `gouache`, `watercolor_pen`
  - 解像度: `1672×941`

manifest/CSV/SHA一覧との照合とPNG読込みを確認済み。
町広場の既存画像は変更しない。制作・承認済み原画像だけを登録する。

- 推奨: 16:9 前後、背景のみ、文字なし。全体を縦横比維持で表示。

manifest の各 facility は次の形式の配列にする。

```json
{"weapon": [{"style": "interior", "path": "res://assets/facilities/weapon.png"}]}
```

施設へ入るごとに読み取り可能な候補から専用 RNG で抽選する。
同一訪問中の再描画・購入・フィルター・人物選択・モーダル操作は保持。
施設ページを離れると終了。再訪問時の連続同一画風も許容する。
ロード・新規開始時は訪問状態を初期化する。セーブ形式は変更しない。
素材未登録・パス不在なら従来表示。試験用既存画像を完成素材として登録しない。
背景と暗色レイヤーはマウス入力を受け取らず、既存 UI を前面に配置する。
