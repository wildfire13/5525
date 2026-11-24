# 拠点スチル受け入れ先

manifest.json の各拠点IDを配列にし、画像受領後に次の形式で登録する。

```json
{"id":"bg_town_astaris","path":"res://assets/towns/bg_town_astaris.png","style":"ローカルマップ"}
```

対象は astaris / east / west / south / north（各1枚・計5枚、解像度 `1920×1080`）。

- `astaris`: `bg_town_astaris.png`（`背景_アスタリス.png` 原本バイト）
- `east`: `bg_village_east.png`（`背景_イース.png` 原本バイト）
- `west`: `bg_village_west.png`（`背景_ウエス.png` 原本バイト）
- `south`: `bg_village_south.png`（`背景_サウス.png` 原本バイト）
- `north`: `bg_village_north.png`（`背景_ノース.png` 原本バイト）

原本の寸法・バイト数・SHA-256 は `source-manifest.json` に記録。
FHD向け横長画像を推奨。文字・施設ボタンは画像に焼き込まない。
建築・施設設定をこのファイルから追加しない。施設は `campaign.locations` を参照する。
表示は縦横比を保持して全体を収め、切り抜きや引き伸ばしをしない。
到着時に候補から選択し、同じ訪問中の施設往復では保持する。戦闘用乱数とセーブ形式には影響しない。
