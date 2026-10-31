"""Bounded local raster imports; character-ID overrides shared by all Tk views."""
import base64
import hashlib
import io
import os
from pathlib import Path
import tempfile
import warnings

MAX_FILE_BYTES = 16 * 1024 * 1024
MAX_PIXELS = 16_000_000
MAX_EDGE = 8192
STORED_EDGE = 256
MAX_PNG_BYTES = 300_000
SAVE_KEY = 'nativePortraits'
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif'}
FORMATS = {'PNG', 'JPEG', 'WEBP', 'BMP', 'GIF'}


class PortraitError(ValueError):
    pass


def pillow():
    try:
        from PIL import Image, ImageOps
    except ImportError as error:
        raise PortraitError('画像の設定・読込には Pillow が必要です。native/requirements-portraits.txt を参照してください。') from error
    return Image, ImageOps


def normalize_raster(data, stored=False):
    """Decode only raster formats, before allocation check dimensions, discard metadata."""
    Image, ImageOps = pillow()
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data), formats=['PNG'] if stored else sorted(FORMATS)) as source:
                width, height = source.size
                limit = STORED_EDGE if stored else MAX_EDGE
                if (width < 1 or height < 1 or max(width, height) > limit
                        or width * height > MAX_PIXELS):
                    raise PortraitError('画像が大きすぎます（各辺8192px・1600万画素まで）')
                # Verify integrity before fully decoding the first frame.
                source.verify()
            with Image.open(io.BytesIO(data), formats=['PNG'] if stored else sorted(FORMATS)) as source:
                source.seek(0)
                source.load()
                result = ImageOps.exif_transpose(source).convert('RGBA')
                result.thumbnail((STORED_EDGE, STORED_EDGE), Image.Resampling.LANCZOS)
                # A fresh image strips ICC, EXIF, comments and unrelated file payloads.
                clean = Image.new('RGBA', result.size)
                clean.paste(result)
                output = io.BytesIO()
                clean.save(output, format='PNG')
                png = output.getvalue()
                if len(png) > MAX_PNG_BYTES:
                    raise PortraitError('変換した画像が大きすぎます')
                return png
    except PortraitError:
        raise
    except (OSError, ValueError, SyntaxError, Image.DecompressionBombError,
            Image.DecompressionBombWarning) as error:
        raise PortraitError('画像を読み込めません。対応する正常な画像ファイルを選んでください。') from error


def read_raster(path):
    path = Path(path)
    if path.suffix.lower() not in EXTENSIONS or not path.is_file():
        raise PortraitError('PNG / JPEG / WebP / BMP / GIF の通常ファイルを選んでください')
    with path.open('rb') as source:
        data = source.read(MAX_FILE_BYTES + 1)
    if len(data) > MAX_FILE_BYTES:
        raise PortraitError('画像ファイルが大きすぎます（16MiBまで）')
    return normalize_raster(data)


def resolve_portrait(images, member):
    """48px fitting box; ally character ID first, then shipped asset fallback."""
    if member.get('side') != 'enemy' and hasattr(images, 'portrait'):
        override = images.portrait(member.get('id'))
        if override is not None:
            return override
    key = ('enemy/enemy_' if member.get('side') == 'enemy' else '') + member.get('image', '')
    if member.get('side') != 'enemy':
        for job in ('scout', 'porter', 'guard', 'mage'):
            for race in ('human', 'elf', 'dwarf'):
                for sex in ('male', 'female'):
                    if (job, race, sex) == ('mage', 'elf', 'male'):
                        continue
                    if member.get('id') == f'recruit-{job}-{race}-{sex}':
                        key = f'characters/{job}-{race}-{sex}-01.png'
    return images.get(key)


class PortraitImages(dict):
    def __init__(self, master, directory):
        super().__init__()
        self.master = master
        self.directory = Path(directory)
        self.pngs = {}
        self.photos = {}

    def _copy(self, png):
        digest = hashlib.sha256(png).hexdigest()
        self.directory.mkdir(parents=True, exist_ok=True)
        target = self.directory / (digest + '.png')
        temporary = None
        try:
            with tempfile.NamedTemporaryFile('wb', dir=self.directory, suffix='.tmp', delete=False) as output:
                temporary = Path(output.name)
                output.write(png)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, target)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
        return digest

    def _photo(self, png):
        from PIL import ImageTk
        Image, _ = pillow()
        with Image.open(io.BytesIO(png), formats=['PNG']) as source:
            source.thumbnail((48, 48), Image.Resampling.LANCZOS)
            return ImageTk.PhotoImage(source, master=self.master)

    def assign(self, uid, path):
        png = read_raster(path)
        photo = self._photo(png)
        self._copy(png)
        self.pngs[uid] = png
        self.photos[uid] = photo

    def clear(self, uid=None):
        # Keep shipped dictionary and content-addressed files for older saves.
        if uid is None:
            self.pngs.clear()
            self.photos.clear()
        else:
            self.pngs.pop(uid, None)
            self.photos.pop(uid, None)

    def portrait(self, uid):
        return self.photos.get(uid)

    def snapshot(self):
        return {'version': 1, 'characters': {
            uid: {'sha256': hashlib.sha256(png).hexdigest(),
                  'png': base64.b64encode(png).decode('ascii')}
            for uid, png in self.pngs.items()}}

    def prepare(self, metadata, allowed_ids):
        """Stage before campaign mutation; never follow paths from save metadata."""
        if metadata is None:
            return {}, {}
        if (not isinstance(metadata, dict) or metadata.get('version') != 1
                or not isinstance(metadata.get('characters'), dict)):
            raise PortraitError('保存画像の形式が正しくありません')
        characters = metadata['characters']
        if not set(characters).issubset(set(allowed_ids)):
            raise PortraitError('保存画像のキャラクターIDが正しくありません')
        pngs, photos = {}, {}
        for uid, entry in characters.items():
            if (not isinstance(entry, dict) or not isinstance(entry.get('png'), str)
                    or len(entry['png']) > 4 * ((MAX_PNG_BYTES + 2) // 3)):
                raise PortraitError('保存画像のサイズ・形式が正しくありません')
            try:
                png = base64.b64decode(entry['png'], validate=True)
            except ValueError as error:
                raise PortraitError('保存画像を読み取れません') from error
            if hashlib.sha256(png).hexdigest() != entry.get('sha256'):
                raise PortraitError('保存画像が破損しています')
            pngs[uid] = normalize_raster(png, stored=True)
            photos[uid] = self._photo(pngs[uid])
        for png in pngs.values():
            self._copy(png)
        return pngs, photos

    def activate(self, prepared):
        self.pngs, self.photos = prepared
