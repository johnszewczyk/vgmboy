#!/usr/bin/env python3
"""Copy or check the portable SB2 presentation assets in the hosted owner."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
sb2 = Path(__file__).resolve().parents[1]
target = sb2.parents[1] / 'MathBook/private-admin/static/accounts'
for name in ('sb-presentation.css', 'sb-presentation.js'):
    source = sb2 / 'Sources/SB2/Resources' / name
    destination = target / name
    if args.check:
        if not destination.exists() or source.read_bytes() != destination.read_bytes():
            raise SystemExit(f'Presentation drift: {destination}')
    else:
        destination.write_bytes(source.read_bytes())
print('SB2/SBONLINE presentation assets match.' if args.check else 'Synced SB2 presentation assets to SBONLINE.')
