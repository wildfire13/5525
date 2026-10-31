# スカウト素材更新 2026-10-31

Drive Share/prot_assets/characters/スカウト の末尾01を採用。02は対象外。PNG原本を無加工で格納（RGBA、幅1024、女の人間/ドワーフは高さ1536、他2048）。

|人物|配布パス|SHA256|
|---|---|---|
|scout-dwarf-female-01|`native/assets/characters/scout-dwarf-female-01.png`|`3b1b97c7f741fac96ff7c8b6621ab3135ac078b0bcbb518a9ff34797344b906d`|
|scout-dwarf-male-01|`native/assets/characters/scout-dwarf-male-01.png`|`fe7f16a1bf0287594830aaf5ce9e67203e55484b093ef1f8cdbd16147df2a7b2`|
|scout-elf-female-01|`native/assets/characters/scout-elf-female-01.png`|`276212df419b6944b06009a3fd158fa2ba042684cae0223fb5eee4a565523826`|
|scout-elf-male-01|`native/assets/characters/scout-elf-male-01.png`|`3d380ad92de88f5ab9ce07f0e18b913d806264f883aa3d316339e9d43bfac686`|
|scout-human-female-01|`native/assets/characters/scout-human-female-01.png`|`cad560664585a1a3d278e3fce62896b7ec3825956ef959520df18bd4323ae5c5`|
|scout-human-male-01|`native/assets/characters/scout-human-male-01.png`|`1c8fa934dd19f5d7bc77c28e52e4a0f964c786c5738da396f5f3fec15ade5f5a`|

- 新24人のスカウト6人へ種族/性別で割当。武器外見は職業判定に使わない。旧人物は性別不明のため既存画像を維持。
- 新規テンプレートと、既存旅/戦闘スナップショットの同一IDに適用。ユーザー個別画像は最優先、敵には転用しない。セーブ形式/性能/装備変更なし。
- Python portrait 10件、file error 2件、roster 6件、6画像テンプレート対応成功。Linux Godot FHD表示18確認/実OSクリック2回。ギルド通常画面と6枚の描画fixtureを区別。
- 証拠 `/workspace/scout-assets-20261031/gui`。画像原本と全身/FHD表示を実見。Windows実機・本人PC起動未確認。
- 先行UIのFHD検証は docs/ui-audit-improvements-20261030.md を参照。同一コードのフル再実行はせず、今回対象を検証。

## push後CIの切り分け

- d3b04a3: Windows 41185554396成功。Linux 41185554400は15分上限超過でcancelled（check annotationで確認）。
- 終了前ログで旧YES/NO検査1件、地図旧位置検査2件を検出。確定操作名と取消結果/装備個数の検査を保持し、地図は常設リスク＋凡例内の移動区間/ホイール方向を検査するよう更新。対象28件とFHD11件成功。
- 1180/960のfacility_npc/feedback_backdrops失敗は今回のFHD限定方針により未対応。既存CIの解像度設定や時間上限は変更しない。全CI成功とは扱わない。
