# 起動環境設定の検証

対象は `cleanup/261114-env` のゲーム作業ツリー。private `.env` は変更・表示しない。

- Python設定検査: 13件合格。環境変数・ローカルJSONとの優先順位、設定再読込、空値、UTF-8 BOM、日本語空白パス、不足時の停止を確認。
- 実ランチャー検査: 12件合格。日本語空白パスの隔離コピーでWindows PowerShellとGodot 4.6.3を使用した。設定は検査用 `.env` に書き、通常起動のゲームプロセスをプロキシでheadlessにした。隔離コピーには10秒後に本来の終了処理を呼ぶタイマーを追加した。
- 3実行ファイルそれぞれの不足、環境変数による上書き、設定差し替え後の再起動、初回・キャッシュ欠損・通常キャッシュでの起動、素材追加、インポート失敗時の停止、終了コード、既存セーブの非変更を確認。証跡は `.cache/env-launcher-checks-7/results.json`。
- 追跡文書にハッシュ付きローカルパスは残っていない。`.env` とPythonキャッシュのignoreを確認した。パス秘匿を検証するテストの架空パスは維持した。
- 実画面での通しプレイ、CI、他PCでの確認は未実施。

再実行は `python -B godot/tests/launcher_config_tests.py`。実ランチャー検査は `godot/tests/launcher_import_checks.py` に `--powershell`、`--godot`、未作成の `--output` フォルダを指定する。出力には実行環境のパスが含まれるため、ローカルのignoredフォルダへ保存する。
