"""Report every tracked Godot script or shader without a tracked UID."""
import os
import subprocess
import sys


def main():
    listing = subprocess.check_output(['git', 'ls-files', '-z', '--', 'godot/'])
    paths = set(listing.split(b'\0'))
    missing = sorted(path + b'.uid' for path in paths
                     if path.endswith((b'.gd', b'.gdshader')) and path + b'.uid' not in paths)
    for path in missing:
        print(f'Missing tracked UID: {os.fsdecode(path)!r}', file=sys.stderr)
    return bool(missing)


if __name__ == '__main__':
    sys.exit(main())
