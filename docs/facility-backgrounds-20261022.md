# 施設背景21枚と床マス判定の統合確認

引継ぎ元: `handoff/pointing-facility-prep-20261022`、
`e8a84fb7b8479a7dbcfe7f17d7bb0a98cbb7dbbe`。
比較対象 main: `e98a76a57a3503c9ab398dfcac1b9116dcaaceaf`。
この時点の差分は申告どおり14ファイル・1コミットで、先行変更との競合はなかった。
作業ブランチは `integration/facility-backgrounds-20261022`。

## 変更と保持したもの

元 Library の7 ZIPから武器屋・防具屋・道具屋・装飾品屋・ギルド・宿屋・出発地図の
3画風ずつを受け入れ、`godot/assets/facilities/manifest.json` に登録した。
PNG21枚は生成原本とバイト単位で一致する。防具屋3枚は1671×941、他18枚は1672×941。
リサイズ・再生成・NPC追加はしていない。既存広場の画像と表示処理、セーブ形式、進行 RNG は変更していない。

引継ぎの専用 RNG・訪問状態・背景入力無視の実装をそのまま使用する。
同一訪問の再描画、購入、フィルター、詳細タブでは背景を保持し、離脱後の再訪問は再抽選する。
連続して同じ画風を引くことも許容する。

受領時には7 ZIPのサイズ・SHA-256・全エントリのCRC・安全なパスを確認した。
共通の manifest、CSV、SHA一覧、READMEは7 ZIPすべてでバイト一致を確認してから、
施設別の隔離フォルダーへ展開した。書類の上書きで相違を隠していない。
書類原本は `docs/facility-backgrounds/`、検証記録は `qa/facility-backgrounds-20261022/`。
自動検証には原本のハッシュ・ファイル名・寸法と7×3登録の整合性確認を追加した。

既存の非同期ホバーテストでは、故障注入用250ms制限が新しいNode接続の起動にも残っていた。
再接続前に通常の15秒へ戻し、故障注入自体の制限と88項目の検証は維持した。
ゲームの接続処理やタイムアウト値は変更していない。

## 検証結果

- 自動ランナー22/22成功。修正後の対象再実行を含む集計を `headless-results.json` に記録。
- 実素材・訪問状態257/257、床マス128/128、非同期ホバー88/88。
- Xorg dummyの隔離画面、Godot4.6.3のOpenGL/llvmpipeで実際に描画し、XTestでOSのマウス入力を送った。
- GUI本検証345/345、OS操作90回、PNG44枚。1920×1080と1180×812それぞれで7施設×3画風を表示した。
- GUI追加検証23/23、OS操作7回、PNG2枚。ギルド詳細3タブでの背景固定、通常の攻撃対象選択と予測、空マスホバー時の対象保持、中ボタンによるカメラ回転と回転後の床マス判定を実OS入力で確認した。
- 各背景から広場への移動と再訪問、商品ドラッグ、購入確認と取消、ギルド人物選択、宿泊確認取消、地図行先選択をOS入力で検証。
- カメラ傾斜0.4/0.7/1.1、画像が重なった人物マスと空マスで、実OSホバーの人物情報とクリック信号が床マスに一致することを検証。
- 画面一覧と原寸画面を目視確認。既存の文字・価格・操作ボタンが読め、背景を入力が通過することを確認した。

画面一覧: `facilities-1920-contact.jpg` と `facilities-1180-contact.jpg`。
44枚の原寸PNGと全ログは隔離証拠フォルダー `/workspace/5525-integration-qa/gui-final/` に保持している。
追加検証は `/workspace/5525-integration-qa/gui-input-extra-fixed/` に保持している。
本検証の床マスクリックは信号を観測し、行動を実行せずに入力先を検証する。
使用したキャンペーンはすべて合成テストデータで、ユーザーの既存セーブは使用していない。

## 再実行

```sh
python3 godot/tests/run_inventory_header_261020.py --evidence /absolute/path/outside/checkout
DISPLAY=:99 python3 godot/tests/run_facility_gui_261022.py --evidence /absolute/path/fresh-gui-evidence
DISPLAY=:99 python3 godot/tests/run_facility_gui_261022.py --script facility_input_extra_261022 --evidence /absolute/path/fresh-input-evidence
```

GUIランナーには独立したX画面、libX11/libXtst、Godot、Node、Python/Pillowが必要。
ランナーは証拠とXDGプロファイルをチェックアウト外へ隔離し、実行したX画面にOS入力を送る。
GUIの初回入力を正しく扱うため、ウィンドウ管理ソフトがない画面ではポインター下のウィンドウへフォーカスを設定する。
ユーザーのPC操作、既存環境の再起動・削除、認証・ネットワーク設定の変更は行っていない。
Windows実機の手操作、音声の聴取、ユーザー実セーブでの試遊は今回の実測範囲に含まない。
