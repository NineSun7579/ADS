"""Generate review provenance from the two frozen epsilon source archives."""
from pathlib import Path
import difflib
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parent
original = {}
archives = {}
for name in ('upstream-source.tgz', 'support.tgz'):
    path = root / name
    archives[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    with tarfile.open(path) as archive:
        for member in archive.getmembers():
            if member.isfile():
                original[member.name] = archive.extractfile(member).read()
manifest = {
    'source_host': 'epsilon',
    'source_path': '/home/epsilon/ads-cross-bench/ads-four-fair-20261104/host',
    'frozen_date': '2026-11-04',
    'source_kind': 'actual ARM source directory, not repository HEAD or HTTP overlay fork',
    'archives_sha256': archives,
    'upstream_files_sha256': {p: hashlib.sha256(b).hexdigest() for p, b in sorted(original.items())},
}
(root / 'SOURCE_PROVENANCE.json').write_bytes((json.dumps(manifest, indent=2) + '\n').encode('utf-8'))
delta = []
for name, data in sorted(original.items()):
    path = root / name
    after = path.read_bytes() if path.exists() else b''
    if after == data:
        continue
    delta.extend(difflib.unified_diff(data.decode('utf-8').splitlines(True),
        after.decode('utf-8').splitlines(True), fromfile='upstream/' + name, tofile='production/' + name))
for path in sorted((root / 'host').rglob('*')):
    name = path.relative_to(root).as_posix()
    if path.is_file() and name not in original:
        delta.extend(difflib.unified_diff([], path.read_text(encoding='utf-8').splitlines(True),
            fromfile='/dev/null', tofile='production/' + name))
(root / 'SOURCE_DELTA.patch').write_bytes(''.join(delta).encode('utf-8'))
