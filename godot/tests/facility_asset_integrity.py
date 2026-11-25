"""Verify all current background bytes against the delivered documents."""
import csv
import hashlib
import json
from pathlib import Path
from PIL import Image

repo = Path(__file__).resolve().parents[2]
docs = Path(__file__).resolve().parent / 'fixtures/facility-backgrounds'
source = json.loads((docs / 'manifest.json').read_text(encoding='utf-8'))
assets = {a['target_path']: a for a in source['assets']}
with (docs / 'facility_style_map.csv').open(encoding='utf-8-sig', newline='') as f:
    rows = list(csv.DictReader(f))
csv_assets = {r['path']: r for r in rows}
sums = {
    name: sha
    for sha, name in (
        line.split() for line in (docs / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines() if line.strip()
    )
}
catalog = json.loads((repo / 'godot/assets/facilities/manifest.json').read_text(encoding='utf-8'))
interior_filenames = {
    'weapon': 'bg_weapon_shop_interior.png',
    'armor': 'bg_armor_shop_interior.png',
    'item': 'bg_item_shop_interior.png',
    'accessory': 'bg_accessory_shop_interior.png',
    'guild': 'bg_guild_interior.png',
    'inn': 'bg_inn_interior.png',
}
facilities = set(interior_filenames)
assert set(catalog) == facilities
assert len(assets) == len(source['assets']) == source['asset_count'] == len(rows) == len(csv_assets) == len(sums) == len(facilities)
assert set(assets) == set(csv_assets) == set(sums)
assert {p.name for p in (repo / 'godot/assets/facilities').glob('*.png')} == {a['filename'] for a in assets.values()}
for facility in sorted(facilities):
    variants = catalog[facility]
    assert len(variants) == 1 and {v['style'] for v in variants} == {'interior'}
    for variant in variants:
        style = variant['style']
        name = interior_filenames[facility]
        path = 'godot/assets/facilities/' + name
        assert variant['path'] == 'res://assets/facilities/' + name
        a, row = assets[path], csv_assets[path]
        data = (repo / path).read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        dims = (1920, 1080)
        assert a['facility'] == row['facility'] == facility
        assert a['style'] == row['style'] == style
        assert a['filename'] == name and len(data) == a['bytes']
        assert digest == a['sha256'] == row['sha256'] == sums[path]
        assert (a['width'], a['height']) == (int(row['width']), int(row['height'])) == dims
        with Image.open(repo / path) as image:
            assert image.format == 'PNG' and image.size == dims
            image.verify()
        print('PASS original background ' + name)
print('PASS all current backgrounds and facility catalog match manifest/CSV/SHA')
