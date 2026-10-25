#!/usr/bin/env python3
"""Validate approved individual artwork without private sources or external services."""
import hashlib
import json
from pathlib import Path
import struct
import zlib

EXPECTED_ART = {'archer': {'category': 'skills',
            'sha256': '25865e296c5cc7ea937dfd23c90c8b88aeebbc21094cebb824b7dc46f65bcd45',
            'target_ids': ['archer']},
 'armor-cloth': {'category': 'wearables',
                 'sha256': '3f50510cceda56178c89854c7d7ddd365c1e3f76f37e6f858b79794e36accff4',
                 'target_ids': ['armor-cloth']},
 'armor-iron-2': {'category': 'wearables',
                  'sha256': '56b9ae84911dc401e1e995654363f0f42e15358574640723a8500c86f9b81143',
                  'target_ids': ['armor-iron-2']},
 'armor-leather-1': {'category': 'wearables',
                     'sha256': 'e26f8df88fc9d0f6c134d603411ab9cd3dce3c25478c712cbe2bd24755cd2655',
                     'target_ids': ['armor-leather-1']},
 'armor-silver-1': {'category': 'wearables',
                    'sha256': '18df366341900af8f98f5c4fe271f317d652360bf9735951bfbdb34344f59cd7',
                    'target_ids': ['armor-silver-1']},
 'battleline-shield': {'category': 'weapons',
                       'sha256': 'f845de37003f28afc97aab5462bab2a3fef777e8839436a7c1244a772f35434c',
                       'target_ids': ['battleline-shield']},
 'bow-silver-2': {'category': 'weapons',
                  'sha256': '993cb7ffccbb420846cd2a36a6fa09e8774c5281d9e405c87f407dcb3f8a31eb',
                  'target_ids': ['bow-silver-2']},
 'bow-wood': {'category': 'weapons',
              'sha256': '26f255bcc5f64e22885d5d4300aa754c71a8a7bf8c6da4624c9c4a1b6a60d861',
              'target_ids': ['bow-wood']},
 'bow-wood-1': {'category': 'weapons',
                'sha256': '729d7c1df7430bb26687b319e4b03de820b42c41c760f8acad16801ba02cdab9',
                'target_ids': ['bow-wood-1']},
 'breaker-hammer': {'category': 'weapons',
                    'sha256': 'd38c1050a2b0ff12e768dbaa382ffcadc10c460eb29c15d97b9bda8cf3839a16',
                    'target_ids': ['breaker-hammer']},
 'cloth-feet': {'category': 'wearables',
                'sha256': '5c000c18f144f09040e7b8ba8c5c7ea108391310da6fe44a65ffaab0f8387c4a',
                'target_ids': ['cloth-feet']},
 'cloth-head': {'category': 'wearables',
                'sha256': 'fc3139d4b74873e18f9eaf2d936c29170716bd1410cde08f83e4d9463ebfa966',
                'target_ids': ['cloth-head']},
 'cloth-lowerBody': {'category': 'wearables',
                     'sha256': 'e327379641f23cd1bdeabb16a21f767d6a17f72545340a89166a42bae4c1d90a',
                     'target_ids': ['cloth-lowerBody']},
 'dagger-wood': {'category': 'weapons',
                 'sha256': '96718ec513ddef8eb17c32fce066fbdda513e8e25305c6290561153f41c64390',
                 'target_ids': ['dagger-wood']},
 'defenseLine': {'category': 'skills',
                 'sha256': '7d672c68a11f9be4223080c7fbd88ff62a20ab0bb06ad651ab192173520fcc10',
                 'target_ids': ['defenseLine']},
 'firstStride': {'category': 'skills',
                 'sha256': 'fbd26f4581cd555a1c684e09fef8ccef3ff2996f807f1476f35eec4ad5e90a0f',
                 'target_ids': ['firstStride']},
 'grapple': {'category': 'skills',
             'sha256': '076f9da05a625ecec13b73b53042de78c38c840eca6ba6207c8021bd4876b469',
             'target_ids': ['grapple']},
 'grappling-rope': {'category': 'weapons',
                    'sha256': '228056deb0b06e641291bd38b7fad36ea288c53bd8495393f29191ead197cc79',
                    'target_ids': ['grappling-rope']},
 'greatsword-wood': {'category': 'weapons',
                     'sha256': 'fea2932785d6b23d88cc0ed95fe48830bdc1a7ea026968c07d6f8166e4c424f0',
                     'target_ids': ['greatsword-wood']},
 'guard': {'category': 'skills',
           'sha256': 'c66b51566e5ef379d34045f085320b55b3812548153eef7c02566e61d7b577ac',
           'target_ids': ['guard']},
 'guard-shield-iron-1': {'category': 'weapons',
                         'sha256': '10fcdaae486ba7432f0ed1b341bb1e5672daeec447500a42b45f354dee194ec4',
                         'target_ids': ['guard-shield-iron-1']},
 'guard-shield-wood': {'category': 'weapons',
                       'sha256': '2cbc62354361bf4b1b73235ed66864f5595da69c97bf122800dc7a3dd755f857',
                       'target_ids': ['guard-shield-wood']},
 'hammer-iron-1': {'category': 'weapons',
                   'sha256': 'b58208ed9c1df5d3a92cc1dbb3d4462e560721e9464b075758aecda113df9529',
                   'target_ids': ['hammer-iron-1']},
 'hammer-wood': {'category': 'weapons',
                 'sha256': '3b416ed57e4685f9ae0b22c3d713fcff3ec5595d0a0298e6eb5a7e4a8d9f7fbb',
                 'target_ids': ['hammer-wood']},
 'healingCross': {'category': 'skills',
                  'sha256': '7f20114994d13485e25045c39860aa36299b2e77bc8fdadfe4b6d07869ba5a87',
                  'target_ids': ['healingCross']},
 'invasion': {'category': 'skills',
              'sha256': '15075f1fb9a7fd53fa54f1245839e5802d7e77dba71f74b04328f849d0e1cf14',
              'target_ids': ['invasion']},
 'invasion-charm': {'category': 'wearables',
                    'sha256': 'f2c1ba59c117f91daa5bece8142a5587f4b6741c65502159c4d69b0a70c33506',
                    'target_ids': ['invasion-charm-1', 'invasion-charm-2']},
 'itemUse': {'category': 'skills',
             'sha256': '6c55521ad435ca412328dbf29e6ee68e154064d363b10498a8a9f2fd0c50ac03',
             'target_ids': ['itemUse']},
 'javelin-wood': {'category': 'weapons',
                  'sha256': 'd462a7bbe9a4a0e4f79f06bf955414647cd95db7916fbc335f027de6bce1dad0',
                  'target_ids': ['javelin-wood']},
 'knockback': {'category': 'skills',
               'sha256': '42a88e043fa787915bc9719198d698b91f3e7d4ac27eeabd68df014c39529a34',
               'target_ids': ['knockback']},
 'kungfu-pants': {'category': 'wearables',
                  'sha256': '03af1bcd87a7339d42484b21251292c16c5f435abaa6f53994ec5c54188f8076',
                  'target_ids': ['kungfu-pants']},
 'kungfu-pants-1': {'category': 'wearables',
                    'sha256': '38c0637dc6ff50a4b40204e127a529695177d4cae5f041f534e557760d1bd426',
                    'target_ids': ['kungfu-pants-1']},
 'kungfu-pants-2': {'category': 'wearables',
                    'sha256': '1dce8d446330e7db1abbbad636e49b1c0e95140b49588fffa896dc0d10988839',
                    'target_ids': ['kungfu-pants-2']},
 'kungfu-pants-3': {'category': 'wearables',
                    'sha256': 'dc340fd2dcb59e31a9d7e856b9a986621a0ffa4f039a6b533d167dbf3ac31dc4',
                    'target_ids': ['kungfu-pants-3']},
 'lone-ring': {'category': 'wearables',
               'sha256': 'd868783bb166c192be627c9e99d40f5dfdb026d235b5e30de9261c162e4ed9ad',
               'target_ids': ['lone-ring-1', 'lone-ring-2']},
 'loneWolf': {'category': 'skills',
              'sha256': '8202472d7bc63808582f9a04ed2b0fec31629f5d3d11cb75c7588209f4fca81c',
              'target_ids': ['loneWolf']},
 'longspear-wood': {'category': 'weapons',
                    'sha256': '6773afe5315fada0354ebb91f51f56543ee2d1522a45e24ff3a470bc9ea4aec2',
                    'target_ids': ['longspear-wood']},
 'manaGift': {'category': 'skills',
              'sha256': '6bc6578f2b78bd38a4e3056e5c6c6900cf443f033444fdfdcd7569a05e38409a',
              'target_ids': ['manaGift']},
 'partner-dagger': {'category': 'weapons',
                    'sha256': '9eccd7a410221f2d0ff16ec5f99a38fa45eeab51f74fd3c0e34bcb7d6c4f7c6a',
                    'target_ids': ['partner-dagger']},
 'pincer': {'category': 'skills',
            'sha256': '557eb37f5b38e48b3f15912e7fafad4db92728dce47b0ab01dbd4d3c23374ff5',
            'target_ids': ['pincer']},
 'pioneer-gloves': {'category': 'wearables',
                    'sha256': '9376001d5a3a44e713589f5a7d485a7a9ce044bf38ff113f90517c6ed091f7a9',
                    'target_ids': ['pioneer-gloves-1', 'pioneer-gloves-2']},
 'poleVault': {'category': 'skills',
               'sha256': 'b21578424c36782a80f6fb569a50eeda7069f0865ac6044f42ea933da352a1c5',
               'target_ids': ['poleVault']},
 'porter-kit': {'category': 'weapons',
                'sha256': 'd0b074f8664e74d44bbe52680b728e44707496b13615cd48ddc23911d1d4c78b',
                'target_ids': ['porter-kit']},
 'rest-staff': {'category': 'weapons',
                'sha256': '08739aa475d6dd8b590852e3ff3df9ef04e2a6a4b320dadbf087ca04f882a7b1',
                'target_ids': ['rest-staff']},
 'retreatSlash': {'category': 'skills',
                  'sha256': '2a7d03e0cb5ad98708e9e6268acaff2dfce6257ec109d5d55dde472bd778b686',
                  'target_ids': ['retreatSlash']},
 'return-ring': {'category': 'wearables',
                 'sha256': '3cc64459e4cd98acaa46f1021060432c0e29693f04fc50b59a107fdf286b4f24',
                 'target_ids': ['return-ring-1', 'return-ring-2']},
 'returnHome': {'category': 'skills',
                'sha256': 'f42b5f1b966dc8184a9b07d3796aea6edf9bd3cbbe5f5705f7971033d5ce1352',
                'target_ids': ['returnHome']},
 'sharing-tome': {'category': 'weapons',
                  'sha256': '5ae63104a831e7f3c37499cde70959d9da7c31325ab9a23f2404eaed2c0e6cd7',
                  'target_ids': ['sharing-tome']},
 'spear-wood': {'category': 'weapons',
                'sha256': '15466522b1a751b8b594da0a7395d443b931db3683f1b721c91151a2b80d98c3',
                'target_ids': ['spear-wood']},
 'splitShot': {'category': 'skills',
               'sha256': '72d0a97064111c992515634a3cd6ffc5fb07991b091f30096378494c93ecc6e4',
               'target_ids': ['splitShot']},
 'staff-silver-1': {'category': 'weapons',
                    'sha256': 'b89418bd238d531d50464961f58f35f3adf53be4547bef6a78d53c6825c80d2f',
                    'target_ids': ['staff-silver-1']},
 'staff-wood': {'category': 'weapons',
                'sha256': 'c0ae0cf554afc0d90e51e7db5d4ba89cc45faafa366a4624de5e923670397c29',
                'target_ids': ['staff-wood']},
 'stamp': {'category': 'skills',
           'sha256': '594b4b2688bdd2d88572b80c16650df194285709bfca51294140ead8f8818eaf',
           'target_ids': ['stamp']},
 'swift': {'category': 'skills',
           'sha256': '9c77f360a62336db249155df118dd1943647890dea539425c41d9c41bdce7549',
           'target_ids': ['swift']},
 'swift-boots': {'category': 'wearables',
                 'sha256': '9c83c75e0756bda323b5eb2ba41f5a1c217a23a9dac13cd479950008fe383702',
                 'target_ids': ['swift-boots']},
 'sword-iron-1': {'category': 'weapons',
                  'sha256': '0e37898c6d2fd2707062562f7af82acbad5aac3a2481575f5a25bad7270a4231',
                  'target_ids': ['sword-iron-1']},
 'sword-wood': {'category': 'weapons',
                'sha256': '6ec0f992df3184ee8be8553be1327adff898a857ee30e3eadd7aea28d2af5c04',
                'target_ids': ['sword-wood']},
 'twin-bow': {'category': 'weapons',
              'sha256': '8bec2c4d06452e37dfa5bbec699ea19afad90d91e394a24b8eec3bd4f6f50da0',
              'target_ids': ['twin-bow']},
 'undertow-sword': {'category': 'weapons',
                    'sha256': 'dce64745f30b61334997340a9a55883a5dde5d108eb1ac13d211669b1d657c6d',
                    'target_ids': ['undertow-sword']},
 'victory-earring': {'category': 'wearables',
                     'sha256': '365ab50f04cec79a4992cf84f8153a05127e6444c9a50d8c8e7ab95b155375d2',
                     'target_ids': ['victory-earring-1', 'victory-earring-2']},
 'victoryBreath': {'category': 'skills',
                   'sha256': 'b52d63be15472c2799943a5ce8416d888c3a78c0b3efb70419b8e09619841fbc',
                   'target_ids': ['victoryBreath']}}
EQUIPMENT_IDS = ['armor-cloth',
 'armor-iron-2',
 'armor-leather-1',
 'armor-silver-1',
 'battleline-shield',
 'bow-silver-2',
 'bow-wood',
 'bow-wood-1',
 'breaker-hammer',
 'cloth-feet',
 'cloth-head',
 'cloth-lowerBody',
 'dagger-wood',
 'grappling-rope',
 'greatsword-wood',
 'guard-shield-iron-1',
 'guard-shield-wood',
 'hammer-iron-1',
 'hammer-wood',
 'invasion-charm-1',
 'invasion-charm-2',
 'javelin-wood',
 'kungfu-pants',
 'kungfu-pants-1',
 'kungfu-pants-2',
 'kungfu-pants-3',
 'lone-ring-1',
 'lone-ring-2',
 'longspear-wood',
 'partner-dagger',
 'pioneer-gloves-1',
 'pioneer-gloves-2',
 'porter-kit',
 'rest-staff',
 'return-ring-1',
 'return-ring-2',
 'sharing-tome',
 'spear-wood',
 'staff-silver-1',
 'staff-wood',
 'swift-boots',
 'sword-iron-1',
 'sword-wood',
 'twin-bow',
 'undertow-sword',
 'victory-earring-1',
 'victory-earring-2']
SKILL_IDS = ['archer',
 'defenseLine',
 'firstStride',
 'grapple',
 'guard',
 'healingCross',
 'invasion',
 'itemUse',
 'knockback',
 'legSweep',
 'loneWolf',
 'mage',
 'manaGift',
 'pincer',
 'poleVault',
 'porter',
 'retreatSlash',
 'returnHome',
 'scout',
 'splitShot',
 'stamp',
 'swift',
 'victoryBreath']
PRESERVED = {'legSweep': '20a393ac7ef5989df343e47e71faacbe1fbd42c53ef6a5072e8ebdc408af859d',
 'mage': '586af5ffe0f73eeef60f939291ca799c017722bb8d8cd7eda5bd1619a30bc210',
 'porter': 'f94cbe8428783c66c70d537588446b05008da8fc6b0f50ada743669a2f57346c',
 'scout': 'f19332042982c9a267843fe4810849609a1e6844d60f6abf0cbb74f1100559bf'}
FIST_HASH = 'abea31c8d7bb2bb38129102bf86554f905bd39eabb4362309c761efed44d9bdb'
LEVELS_HASH = '040e7ca070021403216c6180ba9a95c517a09c2ec02411551436ce9a53a39567'


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def rgba_png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    offset, packed = 8, bytearray()
    while offset < len(data):
        size = int.from_bytes(data[offset:offset + 4], "big")
        kind = data[offset + 4:offset + 8]
        content = data[offset + 8:offset + 8 + size]
        assert zlib.crc32(kind + content) & 0xffffffff == int.from_bytes(data[offset + 8 + size:offset + 12 + size], "big"), path
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", content)
            assert (width, height, depth, color, compression, filtering, interlace) == (64, 64, 8, 6, 0, 0, 0), path
        if kind == b"IDAT":
            packed.extend(content)
        offset += size + 12
        if kind == b"IEND":
            break
    raw = zlib.decompress(packed)
    assert len(raw) == 64 * 257, path
    rows, prior = [], [0] * 256
    for y in range(64):
        filter_type = raw[y * 257]
        row = list(raw[y * 257 + 1:(y + 1) * 257])
        for x in range(256):
            left, above, corner = row[x - 4] if x >= 4 else 0, prior[x], prior[x - 4] if x >= 4 else 0
            if filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                p = left + above - corner
                distances = [abs(p - left), abs(p - above), abs(p - corner)]
                predictor = [left, above, corner][distances.index(min(distances))]
            else:
                assert filter_type == 0, path
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        rows.append(row)
        prior = row
    return rows


def main():
    godot = Path(__file__).resolve().parents[1]
    root = godot / "assets/individual_icons"
    manifest = json.loads((root / "manifest.json").read_text())
    recipes = json.loads((godot / "assets/approved_v56/recipes.json").read_text())
    mapping = json.loads((godot / "assets/equipment_icons_placeholder/mapping.json").read_text())
    assert set(manifest) == {"version", "runtime_size", "preserved_skills", "equipment", "skills"}
    assert manifest["version"] == 1 and manifest["runtime_size"] == [64, 64]
    assert sorted(manifest["preserved_skills"]) == sorted(PRESERVED)
    assert len(manifest["equipment"]) == 42 and len(manifest["skills"]) == 19
    entries = manifest["equipment"] + manifest["skills"]
    assert len({e["id"] for e in entries}) == 61
    assert {e["id"] for e in entries} == set(EXPECTED_ART)
    assert set(recipes["equipment"]) == set(EQUIPMENT_IDS) == set(mapping)
    assert set(recipes["skills"]) == set(SKILL_IDS)
    assert digest(recipes["fist"]) == FIST_HASH
    assert {key: digest(recipes["skills"][key]) for key in PRESERVED} == PRESERVED
    assert digest({key: value.get("levels", {}) for key, value in recipes["skills"].items()}) == LEVELS_HASH
    expected_files, equipment_targets, skill_targets = set(), [], []
    paths = {}
    for e in entries:
        expected = EXPECTED_ART[e["id"]]
        assert e["sha256"] == expected["sha256"]
        assert sorted(e["target_ids"]) == sorted(expected["target_ids"])
        assert e["category"] == expected["category"]
        assert e["path"].startswith("res://assets/individual_icons/") and ".." not in e["path"].split("/")
        path = godot / e["path"].removeprefix("res://")
        assert path.suffix == ".png" and path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == e["sha256"], e["id"]
        pixels = rgba_png(path)
        alpha = [row[x] for row in pixels for x in range(3, 256, 4)]
        assert min(alpha) == 0 and max(alpha) == 255, e["id"]
        if e["id"] in ["archer", "itemUse"]:
            reserved = [(x, y, pixels[y][x * 4 + 3]) for y in range(21) for x in range(43, 64) if pixels[y][x * 4 + 3]]
            # Preserve the approved PNG exactly, including five faint edge pixels.
            expected_edge = [] if e["id"] == "archer" else [(43, 14, 1), (43, 15, 1), (43, 18, 4), (43, 19, 4), (43, 20, 3)]
            assert reserved == expected_edge, e["id"]
        assert path not in expected_files, "art files must not alias distinct entries"
        expected_files.add(path)
        section = "equipment" if e in manifest["equipment"] else "skills"
        fields = {"id", "name", "target_ids", "category", "path", "sha256"}
        assert set(e) == fields | {"levels"}, e["id"]
        if section == "equipment":
            assert e["levels"] == [], e["id"]
        if section == "skills":
            assert sorted(e["levels"]) == sorted(recipes["skills"][e["id"]].get("levels", {})), e["id"]
        (equipment_targets if section == "equipment" else skill_targets).extend(e["target_ids"])
        for target in e["target_ids"]:
            spec = recipes[section][target]
            assert spec["base"] == e["path"] and "crop" not in spec and "badge" not in spec, target
            if section == "equipment":
                assert mapping[target] == e["path"], target
            paths[target] = e["path"]
    assert sorted(equipment_targets) == EQUIPMENT_IDS
    assert sorted(skill_targets) == sorted(set(SKILL_IDS) - set(PRESERVED))
    assert set(root.rglob("*.png")) == expected_files
    assert len(expected_files) == 61 and len(set(paths[k] for k in EQUIPMENT_IDS)) == 42
    assert not any(key in paths for key in ["fist", "fist-1", "empty", "none"])
    print("PASS individual icons: 61 exact PNGs, 47 equipment IDs, 23 skills, alpha, hashes, preserved art/levels/fist and mappings")


if __name__ == "__main__":
    main()
