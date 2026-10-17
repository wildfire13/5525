# 起動前のアセット import

`Start-5525.cmd` は `launch.ps1` を通じ、検出済み Godot で
`--headless --path <godot> --editor --import` が終了するまで待ってからゲームを起動する。
PNG と `.import` を pull しても、Git 管理外の `.godot` キャッシュは生成されないため、
初回・更新後ともにこの工程が必要。変更のないアセットには Godot の増分 import が適用される。

import の非ゼロ終了、またはログの `ERROR:` / `SCRIPT ERROR:` を検出した場合は
ゲームを起動せず、ログ内容と一時ファイルの保存先を表示する。
非ゼロの import 終了コードは保持し、ログだけにエラーがある場合は 1 を返す。
成功した import の一時ログは削除する。ゲームの終了コードは従来どおり返す。
`-Check` は依存関係の確認だけを行い、`-SmokeTest` は import 後に既存テストを実行する。
セーブやユーザー設定を削除する処理は追加していない。

## 回帰検証

リポジトリルートで次を実行する。出力先は未作成のディレクトリを指定する。

```text
python godot/tests/launcher_import_checks.py --powershell <powershell.exeまたはpwsh> --godot <Godot実行ファイル> --output <検証保存先>
```

テストは Git のソースを独立した空白入りパスへ展開し、実際の PowerShell ランチャーを起動する。
Godot 呼び出しを記録するプロキシを介し、通常起動には headless と自動終了を追加する。
import とアセットロードは本物の Godot で実行する。失敗時の制御と終了コードはプロキシで注入する。
全キャッシュなし、新規装備42点だけ欠落、既存キャッシュあり、新規 PNG の追加、
import 失敗2種、ゲーム終了コード、`-Check` の8ケースを確認する。
ユーザーデータは検証用ディレクトリに隔離する。

今回の実測: Linux PowerShell 7.4.13 / Godot 4.6.3 で8ケース成功。
各正常ケースで装備42点＋既存52点を実ロードし、追加 PNG ケースでは43点＋52点を確認。
Windows PowerShell 5.1、Windows CMD 経由、実画面での起動は別途確認が必要。
