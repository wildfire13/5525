"""Raster safety and save portability; generated fixtures, no user files."""
import io
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from portraits import MAX_FILE_BYTES, PortraitError, normalize_raster, read_raster

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

    def fixture(self, name='face.png', color=(255, 20, 40, 90), size=(160, 80)):
        path = self.folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new('RGBA', size, color).save(path)
        return path

    def test_transparency_aspect_and_metadata(self):
        path = self.fixture(size=(640, 320))
        with Image.open(io.BytesIO(read_raster(path))) as image:
            self.assertEqual(image.size, (256, 128))
            self.assertEqual(image.getpixel((50, 50))[3], 90)
            self.assertFalse(image.info)
    def test_corrupt_unsupported_and_oversize(self):
        for name, payload in [('bad.png', b'not an image'), ('script.py', b'print(1)'),
                              ('large.png', b'x' * (MAX_FILE_BYTES + 1))]:
            path = self.folder / name
            path.write_bytes(payload)
            with self.assertRaises(PortraitError):
                read_raster(path)

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
