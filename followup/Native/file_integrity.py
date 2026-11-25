"""Elias Calboreanu. Standard-library integrity helper for MATLAB without Java."""
from pathlib import Path
import hashlib
import sys


def main():
    operation, source, target = sys.argv[1:]
    if operation == 'hash':
        digest = hashlib.sha256(Path(source).read_bytes()).hexdigest()
        return 0 if digest == target else 2
    if operation == 'publish':
        payload = Path(source).read_bytes()
        try:
            with Path(target).open('xb') as stream:
                stream.write(payload)
        except FileExistsError:
            return 3
        return 0
    raise ValueError('Unknown operation')


if __name__ == '__main__':
    sys.exit(main())
