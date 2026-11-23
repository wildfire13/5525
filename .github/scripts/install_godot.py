"""Install the verified Godot release into the ephemeral hosted runner."""
import hashlib
import os
from pathlib import Path
import platform
import urllib.request
import zipfile

VERSION = '4.7.2-stable'
RELEASES = {
    'Linux': ('linux.x86_64', 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4'),
    'Windows': ('win64.exe', '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'),
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
