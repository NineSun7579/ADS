"""One-time provenance-checked import; not required on a recipient PC."""
from pathlib import Path
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
BASE = Path('C:/nh_build/v10_lane_io_scratch_build_20261103')
REFERENCE = Path('C:/nh_build/v10_lane_io_ctrlchain8_20261103')

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def main():
    assert not (ROOT / 'source').exists(), 'Refuse to overwrite existing delivery'
    project = (BASE / 'project_input_timingfix.pds').read_text()
    listed = {name.removeprefix('../') for name in re.findall(r'\((?:_file|_ip|_ip_source_item) "([^"]+)"', project)}
    pins = json.loads((REFERENCE / 'prepared_plan.json').read_text())['immutable_inputs']
    manifest = json.loads((BASE / 'source_manifest_scratch.json').read_text())
    imported = []
    omitted = []
    for item in manifest:
        name = item['path']
        source = BASE / name
        assert sha(source) == item['sha256'] == pins[str(source)], name
        # Keep generated HDL, IP metadata, initialization/constraint and referenced files.
        # Drop only unreferenced backups, caches, simulator C binaries and generator logs.
        skip = ('.bak_' in name or '__pycache__' in name or source.suffix in ('.pyc', '.lib', '.so', '.log')) and name not in listed
        if skip:
            omitted.append(name)
            continue
        target = ROOT / name
        target.parent.mkdir(parents=True, exist_ok=True)
        assert not target.exists(), name
        shutil.copy2(source, target)
        imported.append(dict(path=name, bytes=target.stat().st_size, sha256=sha(target)))
    assert listed <= {item['path'] for item in imported}, sorted(listed - {item['path'] for item in imported})
    (ROOT / 'project').mkdir()
    # An unrun, source-only project retains original setup/options, not generated DB state.
    (ROOT / 'project/top.pds').write_text(project, encoding='utf-8')
    (ROOT / 'reference').mkdir()
    for name in ('REVIEW_MAPPING_INDEPENDENT.md', 'BITGEN_ARTIFACT_REVIEW.md', 'pnr.tcl', 'sta_full.tcl'):
        shutil.copy2(REFERENCE / name, ROOT / 'reference' / name)
    (ROOT / 'reference/import_provenance.json').write_text(json.dumps(dict(
        source_project=str(BASE / 'project_input_timingfix.pds'), source_project_sha256=sha(BASE / 'project_input_timingfix.pds'),
        prepared_plan_sha256=sha(REFERENCE / 'prepared_plan.json'),
        reference_bitstream_sha256='3ccdaa213355d9cf1955701993d7e1a3b8826f48fde04d545855ab3712abf50f',
        reference_mapped_sha256='88695aba7c5a3de95e562f6a1a4596b2a8023a2675448e3ff07939061a0d7d45',
        omitted=omitted, copied_files=imported, no_prebuilt_design_database=True), indent=2), encoding='utf-8')
    shutil.copy2(BASE / 'review_timing.py', ROOT / 'tools/review_timing.py')
    print('Imported', len(imported), 'files;', sum(item['bytes'] for item in imported), 'bytes; omitted', len(omitted))

if __name__ == '__main__':
    main()
