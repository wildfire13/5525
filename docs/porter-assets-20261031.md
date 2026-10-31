# ポーター素材更新 2026-10-31

Drive Share/prot_assets/characters/ポーター（folder 1a_l-MVdk32lNivHVs9jnPhF3p--xO4P4）の末尾01を採用。ドワーフ女01_02は対象外。全6枚RGBA・1024×1536、原本を無加工で格納。

|配布パス|SHA256|
|---|---|
|`native/assets/characters/porter-dwarf-female-01.png`|`b77facd10a77bcd2afc95cc40734fcf4efd72fee7a65678b74f0f3eff5383e7e`|
|`native/assets/characters/porter-dwarf-male-01.png`|`21213c6b3776c2c9436585a5da18fbb6ed68bc68724d97a29b48185b3a750c9b`|
|`native/assets/characters/porter-elf-female-01.png`|`e7de59956923a204b3c2c197f7dfbc3f7319273d99c37b5a880669932fa3a7ff`|
|`native/assets/characters/porter-elf-male-01.png`|`23cb2951edb31f86f0840e1241ba030df3a0259853ef9e5956979946d26b640a`|
|`native/assets/characters/porter-human-female-01.png`|`484384517d1c830f79e5208ce3653a032a10937bf975b7f3a7d39622e984d9ea`|
|`native/assets/characters/porter-human-male-01.png`|`dfd96ba8bf3a6ce370f1415c89f31a13ea144299e8741303bc5a755118e74f8a`|

- 人間/エルフ/ドワーフ×男女を同じrecruit IDへ割当。旧旅/戦闘の汎用画像名も解決。個別画像を優先し、旧性別不明人物と敵は変更しない。
- portrait10テスト（12画像の解決/個別設定優先を含む）、roster6チェック、Godot FHD18チェック/実OSクリック2回成功。ギルド実画面と全身描画fixtureを実見。縦横比維持、原本の足/荷物は削らない。
- 証拠 /workspace/porter-assets-20261031/gui。本人PC/セーブは操作せず、音OFF。Windows実画面未確認。
- 先行1942ae2のLinux run41186687425は15分上限でcancelled。更新した2検査は通過、残る失敗は1180幅の2スイート。先行run終了を確認してから追加pushし、実行中CIを取り消さない。
