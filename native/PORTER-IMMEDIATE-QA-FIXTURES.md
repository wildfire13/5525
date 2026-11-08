# ポーター基準・即時方式 Windows QA fixture

下記の JSON はすべて `generate_porter_qa_fixtures.cjs` が作る合成データです。ユーザーの実セーブや元のPCフォルダには触れません。fixture のロード時に表示される既存データは、作業用の隔離環境でのみ確認してください。

## 再現・回帰コマンド

隔離 worktree の `native` ディレクトリで実行します。

```powershell
node .\test_campaign_rule_migration.cjs
python -m unittest -v test_campaign_formation
$env:NATIVE5525_AUDIO_OFF = "1"
godot --headless --path ..\godot --script res://tests/porter_formation_regression.gd
```

最初のコマンドは、ポーター最奥到達とポーター戦闘不能が同時に成立する状態を保存 validator で確認してから、次の行動解決で敗北が優先されることを検証します。さらに、現行 `updatePlanRevision` を含む v2 旧戦闘セーブに受注済みクエスト・ポーター所持の荷物・戦闘で消費済みの薬を入れ、アスタリス帰還後も依頼と荷物が残ること、薬が戻らないこと、戦闘報酬が付かないことを確認します。

2つ目のコマンドは実ゲームの Node bridge が返す `formed` と UI 表示文字列を、2人目のポーターを守護枠へ置いた fixture で照合します。2人目のポーターを枠外へ移し、3人目の非ポーターを枠へ配置すると、両方が `3/3 ON` に変わることも確認します。

## Windows GUI の再確認

ゲームの「ロード」から次のチェックイン済み fixture を選び、ロード先は隔離 QA 環境のままにします。

1. `test_fixtures\porter-formation-two-porters.json` を開く。盤面はポーター `22`、2人目のポーター `24`、盾役 `13`、弓役 `33`。陣形の詳細欄は `2/3`・未発動と表示し、2人目のポーターは空き守護枠を満たさないことを確認する。
2. 配置中に2人目のポーターを `14` へ移し、魔法使いを `24` に置く。表示が `3/3 成立` になり、ゲーム判定も同時に成立することを確認する。
3. `test_fixtures\porter-breakthrough-ko-priority.json` を開き、次の味方行動を1回進める。ポーターは最奥マスにいるものの戦闘不能なので、結果は突破勝利ではなく敗北になる。
4. `test_fixtures\legacy-v2-active-quest-battle.json` を開く。アスタリスへ戻り、受注中の依頼と荷物が保持され、既に使った薬が戻らず、移行説明のポップアップが出ないことを確認する。

この3ファイルはテスト用に保存検証を通したものです。ロード後に保存が必要な場合も、別名の一時ファイルに保存し、fixture 原本は上書きしないでください。
