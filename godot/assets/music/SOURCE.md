# 場面別BGM

「BGM対応表」の実装時ファイル名を使う。アスタリスは `local_map/city_01.mp3`、道中の移動と野営は `road_01.mp3` を全曲ループする。配置と道中戦闘では専用曲に切り替え、野営に戻ると道中曲を再開する。

拠点・施設・道中のMP3の割当は `trial_overrides.json`、村への到着と装備試用戦のWAVは `native/assets/music/manifest.json` に記載する。
