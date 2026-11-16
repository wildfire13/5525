# Godot版の起動と動作確認

Windowsではリポジトリ直下の `Start-5525.cmd` からゲームを起動します。Godot・Node.js・Pythonの設定は[本体のREADME](../README.md)を参照してください。

起動環境だけを確認する場合は `Start-5525.cmd -Check`、画面を開かずに起動を確認する場合は `Start-5525.cmd -SmokeTest` を使います。[起動時の素材インポート](LAUNCHER-IMPORT.md)

Godotの回帰検証はリポジトリ直下で `python godot/check.py` を実行します。`--full` を付けるとnative側の回帰検証も実行します。通常の画面QAは現行版の1920×1080で行います。
