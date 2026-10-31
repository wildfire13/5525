# 戦士・魔法使い・店舗NPC差し替え（2026-10-31）

基点: db520e662037549341c74f7d618903e485f9cfc3。ユーザー指定のDrive末尾01原本をバイト変更なしで採用。画像生成・ゲームルール・セーブ形式の変更なし。

戦士6、魔法使い5、店舗5の計16枚。エルフ男性魔法使いの01は未提供のため既存healer.pngを維持。武器屋は既存weapon1=男性/weapon2=女性へ対応し、来店時の独立50%選択を変更しない。装飾品店・ギルドの画像は保持。

|Drive原本|出典ID|採用先|寸法|SHA-256|
|---|---|---|---|---|
|ドワーフ_男_戦士_01.png|1h_HCf4c8cZUhOT_hjmZ6uzH13fnrKbZe|native/assets/characters/guard-dwarf-male-01.png|1024×1536 RGBA|517fdd83ddd698884a742c2d7e085d1a836884659879172da9a4c326558cd90b|
|人間_女_戦士_01.png|1SFQKeYGYtJFiJ0BH6NWmjfo7jpgmXAke|native/assets/characters/guard-human-female-01.png|1024×2048 RGBA|25a7256f9dae352f9afe932e447b3d70cbca60bba00be97ae8cdd642b73ad2a9|
|ドワーフ_女_戦士_01.png|1e0MM8cREJOYT6LfkcfjOT_vb4WagoJYx|native/assets/characters/guard-dwarf-female-01.png|1024×2048 RGBA|c1e9a1ff35a10b47f6518012668b8e61b4d52f6064a0536a1ade42c8f5362909|
|人間_男_戦士_01.png|1x4ZUtEzSFMdix-kMz5A0E9J5pC9KMr5E|native/assets/characters/guard-human-male-01.png|1024×2048 RGBA|cfee69337a5d252e9dc89742dc089ffb26a25854d6588771870ca34c8199f201|
|エルフ_女_戦士_01.png|1R5e8XoCaPGUwADWoKtx-lmYPauwPgbSS|native/assets/characters/guard-elf-female-01.png|1024×1536 RGBA|b1aef4b256790225e42476d2bd18d75efe5d7845ee88bddba13766b29110b9eb|
|エルフ_男_戦士_01.png|15jf89QNIZxgyDtJtzmdML0JW9IJHy_Jx|native/assets/characters/guard-elf-male-01.png|1024×1536 RGBA|79e0f35057d9da3f628e4d80ca3c703b8e5889c054678b27004ee9db0bceba9b|
|ドワーフ_男_魔法使い_01.png|1a46Ddn8ghIPt9LgyumE-_KZtWe8uN15t|native/assets/characters/mage-dwarf-male-01.png|1024×1536 RGBA|16d9eb07b08b0cfa87c76c3201f71e1571a7bf93a846c5c962c357912ad35ab8|
|エルフ_女_魔法使い_01.png|1hbrjcSJQ4nEVlMLKQgAKG_cBQg_qEk1N|native/assets/characters/mage-elf-female-01.png|1024×2048 RGBA|4a56d4149f2c68993511f4af587f0ef5700b1227fc4f10b1d0c98a7af8c1edfc|
|人間_女_魔法使い01.png|1ll6kkMCdL8fu51zxTJgbL5JZTZWyoEy8|native/assets/characters/mage-human-female-01.png|1024×2048 RGBA|09861f05005eea24b788578e6ddc3dd5a81ac2e40785d2b3ed37c324cf0de208|
|人間_男_魔法使い_01.png|16SY7NyPmkHXyhWPW5weC5K1pwj1xibbv|native/assets/characters/mage-human-male-01.png|1024×2048 RGBA|883795aa3e08baa75f0200830e48d7376336656848adedcb2470fe818533fd18|
|ドワーフ_女_魔法使い_01.png|1uYPHmIZOD4Y6Ak21Bao70PbEZBS_Z4an|native/assets/characters/mage-dwarf-female-01.png|1024×1536 RGBA|e128d146c41b5cc1983035481e4e7c8bc5ec846ab30167a876d60818441373fa|
|エルフ_女_宿屋_01.png|1lIZMD4aGIFsalusavqgXVEeq4Yabldm8|godot/assets/facility_npcs/inn.png|1024×1536 RGBA|14eef3707629d7e25b3450b0c323bf68bc038678dcd2bd1fee5c05898b0516f2|
|ドワーフ_女_道具屋_01.png|1d1BVIsiNaWtUaNfJPwp-5zuiah50ifmm|godot/assets/facility_npcs/item.png|1024×1536 RGBA|1582698f06c2fe97f4b4fae69971a83ffbe1b6b561d24b30f970726937014b4a|
|ドワーフ_男_武器屋_01.png|1DEmZveGgcrfOJx2UMs-qdVAaobqcrmfG|godot/assets/facility_npcs/weapon1.png|1024×1536 RGBA|e183701295281ca91138619fc7a2fd4af3dad7dbdbeecc323d7cf81bc6b3c6e3|
|ドワーフ_女_武器屋_01.png|1aJBox6oKeNJH8343xF_5lCal5p6yi9CE|godot/assets/facility_npcs/weapon2.png|1024×1536 RGBA|1de800520136c587ba561f4ad2b8340931c5fe9e9305b0cc590fa2f1d3d2c84b|
|ドワーフ_女_防具屋_01.png|1lf2UEzJVualrzXd_pkj6JPH4WFpReV7c|godot/assets/facility_npcs/armor.png|1024×1536 RGBA|55851f58539ec2372da4bd44e9550ca4732906294bc5c3878c2cf33d8f80a5e0|

## 互換と表示

- 新規候補は新しい画像参照。旧セーブの同じrecruit IDは表示層で対応し、成長・装備等の保存内容は変更しない。個別設定の人物画像が最優先。旧11人物や敵は対象外。
- NPC5枚の口元座標を原画像で採寸し、既存吹き出しの尾の接続先を更新。拡大率・縦横比・既存の下半身の画面外配置は維持。
- 全16原画像とFHD実レンダーを確認。人物一覧は通常OSクリック、全身/顔一覧と全店舗切替は隔離した表示fixtureを使用。自然な全旅程の完走とは区別。

## 検証

- Python portrait 10件、Node roster 6件成功（23画像参照と未提供1枚、個別上書き、旧セーブ互換を確認）。
- 対象Godot facility_npc_regression / speech_tail_regression / updateplan_regression 成功。PNG全7店舗のSHA・寸法・RGBA・総バイト数検査は新原本へ更新し保持。
- GUI fixture初回は試験側が存在しないmage.pngを旧汎用画像として指定し失敗。実在healer.pngへ直して再試験。製品の未提供画像参照は初回からhealer.pngを保持。
- FHD GUI: 人物29確認/OSクリック2回/3画像、店舗79確認/OSクリック7回/7画像が成功。新NPC5画面を実見し顔・本文の非重複と尾の方向を確認。証跡 `/workspace/new-character-assets-20261031/{gui-final,npc-gui}`。
- FHD 1920×1080、音3種OFF。本人PC不使用。Windowsの実UIは未確認。
- CIは現行workflowの全63実行＋後続SQLite検査をそのまま使用（--onlyなし）、15分上限も変更しない。正確なpush SHAのLinux/Windows終端と所要時間を別途報告。
