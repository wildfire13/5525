# ポーターの配置・戦闘回帰

本体の `native` で `python -m unittest -v test_campaign_formation` と `node test_campaign_rule_migration.cjs` を実行する。現行ゲームの新規状態から陣形と戦闘不能時の判定を確認する。Godotの `res://tests/porter_formation_regression.gd` も新規ゲームで2人のポーターを選び、受注・出発して配置画面に入る。

ロード操作を含めて確認する場合は、対象の本体を参照するsave-labでその都度新規作成する。2人のポーターを含む5人で「水門の鐘」を受注し、イースへ出発して配置に入る。2人目のポーターを条件マスから外し、代わりに非ポーターを配置すると、詳細表示とゲーム判定の両方が2/3から3/3へ変わる。
