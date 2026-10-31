"""Raster safety and save portability; generated fixtures, no user files."""
import base64
import hashlib
import io
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

from portraits import (MAX_FILE_BYTES, PortraitError, PortraitImages,
                       normalize_raster, read_raster, resolve_portrait)

try:
    from PIL import Image
except ImportError:
    Image = None


@unittest.skipIf(Image is None, 'Pillow is needed for custom portraits')
class PortraitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.store = PortraitImages(None, self.folder / 'store')
        self.photo_patch = patch.object(self.store, '_photo', side_effect=lambda data: object())
        self.photo_patch.start()
        self.addCleanup(self.photo_patch.stop)

    def fixture(self, name='face.png', color=(255, 20, 40, 90), size=(160, 80)):
        path = self.folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new('RGBA', size, color).save(path)
        return path

    def test_recruit_defaults_old_snapshots_and_override_priority(self):
        for job in ('scout', 'porter', 'guard', 'mage'):
            for race in ('human', 'elf', 'dwarf'):
                for sex in ('male', 'female'):
                    if (job, race, sex) == ('mage', 'elf', 'male'):
                        continue
                    uid = f'recruit-{job}-{race}-{sex}'
                    key = f'characters/{job}-{race}-{sex}-01.png'
                    self.store[key] = object()
                    member = {'id': uid, 'image': job + '.png', 'side': 'ally'}
                    self.assertIs(resolve_portrait(self.store, member), self.store[key])
                    self.store.photos[uid] = object()
                    self.assertIs(resolve_portrait(self.store, member), self.store.photos[uid])
                    with Image.open(Path(__file__).parent / 'assets' / key) as image:
                        self.assertEqual(image.mode, 'RGBA')
                        self.assertEqual(image.width, 1024)
        self.store['healer.png'] = 'missing-original'
        self.assertEqual(resolve_portrait(self.store, {'id':'recruit-mage-elf-male','image':'healer.png'}), 'missing-original')
        self.store['scout.png'] = 'legacy'
        self.assertEqual(resolve_portrait(self.store, {'id': 'scout', 'image': 'scout.png'}), 'legacy')

    def test_transparency_aspect_metadata_and_original_deletion(self):
        path = self.fixture(size=(640, 320))
        self.store.assign('guard', path)
        path.unlink()
        with Image.open(io.BytesIO(self.store.pngs['guard'])) as image:
            self.assertEqual(image.size, (256, 128))
            self.assertEqual(image.getpixel((50, 50))[3], 90)
            self.assertFalse(image.info)
        copied = list(self.store.directory.glob('*.png'))
        self.assertEqual(len(copied), 1)
        self.assertEqual(copied[0].read_bytes(), self.store.pngs['guard'])

    def test_same_filename_different_characters_and_id_not_name(self):
        first = self.fixture('one/face.png')
        second = self.fixture('two/face.png', color=(10, 255, 30, 200))
        self.store.assign('guard', first)
        self.store.assign('guard-2', second)
        self.assertEqual(len(list(self.store.directory.glob('*.png'))), 2)
        self.store['knight.png'] = 'default'
        a = {'id': 'guard', 'name': 'same', 'image': 'knight.png'}
        b = {**a, 'id': 'guard-2'}
        self.assertIsNot(resolve_portrait(self.store, a), resolve_portrait(self.store, b))
        self.store.clear('guard')
        self.assertEqual(resolve_portrait(self.store, a), 'default')
        self.assertIsNotNone(self.store.portrait('guard-2'))
        self.assertEqual(len(list(self.store.directory.glob('*.png'))), 2)

    def test_enemy_and_plain_dictionary_fallback(self):
        self.store.assign('guard', self.fixture())
        self.store['enemy/enemy_knight.png'] = 'enemy'
        self.assertEqual(resolve_portrait(self.store, {'id':'guard','side':'enemy','image':'knight.png'}), 'enemy')
        self.assertEqual(resolve_portrait({'knight.png':'original'}, {'id':'guard','image':'knight.png'}), 'original')

    def test_corrupt_unsupported_and_oversize_leave_assignment_intact(self):
        self.store.assign('guard', self.fixture())
        expected = self.store.snapshot()
        for name, payload in [('bad.png', b'not an image'), ('script.py', b'print(1)'),
                              ('large.png', b'x' * (MAX_FILE_BYTES + 1))]:
            path = self.folder / name
            path.write_bytes(payload)
            with self.assertRaises(PortraitError):
                self.store.assign('guard', path)
            self.assertEqual(self.store.snapshot(), expected)

    def test_huge_declared_dimensions_are_rejected_before_decode(self):
        # Tiny deliberately oversized PNG header, no large allocation.
        header = struct.pack('>IIBBBBB', 100000, 100000, 8, 6, 0, 0, 0)
        chunk = b'IHDR' + header
        payload = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', len(header)) + chunk + struct.pack('>I', zlib.crc32(chunk))
        with self.assertRaises(PortraitError):
            normalize_raster(payload)

    def test_normal_formats_and_gif_first_frame(self):
        for fmt, suffix in [('JPEG','jpg'), ('WEBP','webp'), ('BMP','bmp'), ('GIF','gif')]:
            path = self.folder / ('face.' + suffix)
            Image.new('RGB', (40, 80), 'red').save(path, format=fmt)
            with Image.open(io.BytesIO(read_raster(path))) as normalized:
                self.assertEqual(normalized.size, (40, 80))
                self.assertEqual(normalized.format, 'PNG')
        path = self.folder / 'animated.gif'
        Image.new('RGB', (20, 30), 'red').save(path, save_all=True,
            append_images=[Image.new('RGB', (20, 30), 'blue')], duration=100, loop=0)
        with Image.open(io.BytesIO(read_raster(path))) as normalized:
            self.assertEqual(normalized.getpixel((0,0)), (255,0,0,255))

    def test_save_embeds_pixels_and_restores_into_fresh_directory(self):
        source = self.fixture()
        self.store.assign('guard', source)
        snapshot = self.store.snapshot()
        source.unlink()
        for copied in self.store.directory.glob('*.png'):
            copied.unlink()
        fresh = PortraitImages(None, self.folder / 'fresh')
        with patch.object(fresh, '_photo', return_value=object()):
            fresh.activate(fresh.prepare(snapshot, ['guard', 'guard-2']))
        self.assertEqual(fresh.snapshot(), snapshot)
        self.assertEqual(len(list(fresh.directory.glob('*.png'))), 1)
        fresh.activate(fresh.prepare(None, ['guard']))
        self.assertEqual(fresh.snapshot()['characters'], {})

    def test_malformed_metadata_has_no_state_effect(self):
        self.store.assign('guard', self.fixture())
        expected = self.store.snapshot()
        invalid = [[], {'version':2, 'characters':{}}, {'version':1, 'characters':{'../x':{}}},
                   {'version':1, 'characters':{'guard':{'png':'!', 'sha256':'x'}}},
                   {'version':1, 'characters':{'guard':{'png':'eA==','sha256':'x'}}}]
        for metadata in invalid:
            with self.assertRaises(PortraitError):
                self.store.prepare(metadata, ['guard'])
            self.assertEqual(self.store.snapshot(), expected)

    def test_failed_disk_copy_preserves_previous_assignment(self):
        self.store.assign('guard', self.fixture())
        expected = self.store.snapshot()
        with patch('portraits.os.replace', side_effect=OSError('test denied')):
            with self.assertRaises(OSError):
                self.store.assign('guard', self.fixture('new.png', color=(0, 0, 0, 0)))
        self.assertEqual(self.store.snapshot(), expected)
        self.assertFalse(list(self.store.directory.glob('*.tmp')))


if __name__ == '__main__':
    unittest.main()
