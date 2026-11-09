"""Bounded raster imports for the Godot file adapter."""
import io
from pathlib import Path
import warnings

MAX_FILE_BYTES = 16 * 1024 * 1024
MAX_PIXELS = 16_000_000
MAX_EDGE = 8192
STORED_EDGE = 256
MAX_PNG_BYTES = 300_000
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
