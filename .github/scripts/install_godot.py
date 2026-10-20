"""Install the verified Godot release into the ephemeral hosted runner."""
import hashlib
import os
from pathlib import Path
import platform
import urllib.request
import zipfile

VERSION = '4.6.3-stable'
RELEASES = {
    'Linux': ('linux.x86_64', 'd0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3'),
    'Windows': ('win64.exe', 'e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90'),
}
suffix, digest = RELEASES[platform.system()]
name = f'Godot_v{VERSION}_{suffix}'
destination = Path(os.environ['RUNNER_TEMP']) / 'godot-runtime'
destination.mkdir(parents=True, exist_ok=True)
archive = destination / (name + '.zip')
urllib.request.urlretrieve(
    f'https://github.com/godotengine/godot/releases/download/{VERSION}/{name}.zip', archive
)
if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
    raise SystemExit('Godot archive SHA-256 mismatch')
with zipfile.ZipFile(archive) as bundle:
    bundle.extractall(destination)
executable = destination / (name.replace('.exe', '_console.exe') if os.name == 'nt' else name)
if os.name != 'nt':
    executable.chmod(0o755)
    (destination / 'godot').symlink_to(executable.name)
with open(os.environ['GITHUB_PATH'], 'a', encoding='utf-8') as output:
    output.write(str(destination) + '\n')
with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
    output.write(f'GODOT_BIN={executable}\n')
