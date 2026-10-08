# Windows exportの依存条件（調査のみ）

2026-10-07。現PCでソース実行する候補は動作しますが、配布用exeはまだ作っていません。追加のダウンロード・インストール・署名・認証・有料サービス利用は行っていません。

## 現物で確認した条件

| 項目 | 現状 | export前に必要な作業 |
|---|---|---|
| Godot | 4.6.3.stable.official.7d41c59c4、Compatibility、AMD GPUで可視描画成功 | この版に対応するWindows x86_64 release export templateが必要 |
| テンプレート | `%APPDATA%/Godot/export_templates` は存在するが中は0件 | **追加取得・導入が必要。未実施** |
| export設定 | `export_presets.cfg` は未作成 | Windows Desktop preset、ファイル収録/除外、出力先を候補内の別build場所へ定義 |
| Node | 現PCは25.2.1、旧ランチャー要件は22以上 | 外部Nodeとnative JS/CJS群を実ファイルで配置する。配布先の既存Nodeを使う方式か、Nodeランタイム同梱かを決める |
| Python/Pillow | 現PCはPython3.13.15＋Pillow | 保存JSON/画像正規化アダプターが外部Pythonを起動する。配布先に同等環境を用意するか同梱。画像helperはTk画面を開かない |
| パス解決 | engine_bridge.gd、audio.gd、portraits.gdが `res://../native` を参照。Nodeは既定で `C:/Program Files/nodejs/node.exe` | export後のexe基準の外部データ位置・ランタイム位置を解決する方式へ調整が必要。PCKだけに入れたJS/PythonをOS子プロセスのファイルパスとして渡すことはできない |
| アセット | 旧音声/画像はnative/assetsの実ファイル。旅3WAVとmanifestはGodot assets側 | 原WAVを実行時に読む方式を保持する場合、JSONと生WAVを収録/外置きする設定を明示し、実export上で読む検証が必要。Godot自動importだけで原本パスが保たれるとは仮定しない |
| 文字 | 現PCのフォールバックフォントで日本語を表示 | 配布先でも日本語が読めることを確認。フォント同梱を選ぶ場合は権利とファイルを確認 |
| 個人データ | 候補専用user://、新規ファイルのみ保存 | buildへnative/user-data、旧セーブ、QA fixtures/記録、.gitを混入させない。ユーザー指定のセーブコピーで別名読込検証 |
| 動作確認 | ソース実行のみ検証済み | 開発環境の絶対パスに依存しないクリーン環境、保存/画像/音声9曲/137ボイス/8SE、子Node終了を検証 |

Godot公式4.6文書では、実行可能なexportにはテンプレートとpresetが必要で、JSONなど非リソースファイルの収録フィルターも設定できます。[Exporting projects](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html)

実行時のWAV読込は現在 `AudioStreamWAV.load_from_file` を使用しています。内部PCM形式や読込APIの仕様は[AudioStreamWAV 4.6](https://docs.godotengine.org/en/4.6/classes/class_audiostreamwav.html)を参照。配布ファイル内の存在確認とループ検証は実exportを作る工程で必要です。

## 未実行の分割案

1. Godot 4.6.3用Windows export templateの取得・配置を親へ確認する。現候補への機能移植に追加取得は不要。
2. 外部nativeデータ＋Node/Pythonをどこへ置くか決め、exe起点のパス解決とexport presetを候補に実装する。自己完結した配布物を選ぶ場合は必要ランタイムの取得可否・同梱条件を別途確認する。
3. 新規buildディレクトリにexportし、通常版・個人保存から隔離して試す。予定のコマンド形式は `Godot --headless --path <candidate/godot> --export-release "Windows Desktop" <isolated-build/5525.exe>`。現在preset/templateがないため実行していない。
4. 実ユーザーセーブはユーザー指定コピーで検証。聴感と手動試遊後に、別途配布/通常適用を判断する。

Game Development Studioはこの通常Godot作業には使っていません。CLI未導入のまま、インストールやプロバイダ利用もしていません。
