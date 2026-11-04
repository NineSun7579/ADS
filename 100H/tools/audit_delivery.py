"""Regenerate static dependency audit and integrity manifest after reviewed changes."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]

def main():
    project = ROOT / 'project/top.pds'
    entries = []
    for name in re.findall(r'\((?:_file|_ip|_ip_source_item) "([^"]+)"', project.read_text()):
        path = (project.parent / name).resolve()
        assert path.is_relative_to(ROOT) and path.is_file(), name
        entries.append(path.relative_to(ROOT).as_posix())
    includes = []
    readmem = []
    absolute = []
    for folder in ('source', 'ipcore'):
        for path in sorted((ROOT / folder).rglob('*')):
            if not path.is_file() or path.suffix not in ('.v', '.sv', '.vh', '.vp', '.fdc', '.idf', '.pds', '.settings'):
                continue
            text = path.read_text(errors='replace')
            relative = path.relative_to(ROOT).as_posix()
            for line_number, line in enumerate(text.splitlines(), 1):
                if re.search(r'[A-Za-z]:[/\\]|/home/', line):
                    active = relative in entries
                    if 'localparam INIT_FILE' in line:
                        assert re.search(r'\.c_INIT_FILE\s*\(\s*"NONE"\s*\)', text), relative
                        classification = 'Unused generator metadata; c_INIT_FILE is explicitly NONE; embedded init constants included'
                    else:
                        assert not active, relative
                        classification = 'Inactive example subproject, not referenced by top project'
                    absolute.append(dict(path=relative, line=line_number, text=line.strip(), classification=classification))
                match = re.match(r'\s*`include\s+"([^"]+)"', line)
                if match:
                    name = match.group(1)
                    direct = (path.parent / name).resolve()
                    candidates = [direct] if direct.is_file() else list((ROOT / folder).rglob(Path(name).name))
                    # Vendor simulation templates use a simulation working directory,
                    # and mobile_ddr contains disabled alternative density branches.
                    required = relative in entries or 'init_param' in name
                    if required:
                        assert candidates, (relative, name)
                    includes.append(dict(path=relative, line=line_number, include=name, required=required,
                                         candidates=[p.relative_to(ROOT).as_posix() for p in candidates if p.is_relative_to(ROOT)]))
                if re.search(r'\$readmem[hb]\s*\(', line):
                    readmem.append(dict(path=relative, line=line_number, text=line.strip(),
                                        note='Parameterized generic RAM; branch reads only if INIT_FILE != NONE; see HDL and generated constants'))
    audit = dict(project='project/top.pds', project_entries=len(entries), entries=entries,
                 includes=includes, readmem=readmem, absolute_path_findings=absolute,
                 prebuilt_design_adf=[], encrypted_hdl_static_visibility='Limited: validate with vendor compile after relocation',
                 only_external_build_dependency='Installed licensed PDS and Python standard library')
    (ROOT / 'tools/dependency_audit.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
    files = []
    for path in sorted(ROOT.rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if relative.parts[0] in ('build', 'validation_work', 'validation_relocated') or '__pycache__' in relative.parts:
            continue
        if relative.as_posix() in ('MANIFEST.json', 'validation.json'):
            continue
        assert path.suffix not in ('.adf', '.rtr', '.sbit', '.bit', '.vm', '.pyc'), relative
        files.append(dict(path=relative.as_posix(), bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (ROOT / 'MANIFEST.json').write_text(json.dumps(dict(format=1, files=files), indent=2), encoding='utf-8')
    print('AUDIT', len(entries), 'project entries;', len(includes), 'includes;', len(absolute), 'classified absolute literals')
    print('MANIFEST', len(files), 'files;', sum(item['bytes'] for item in files), 'bytes')

if __name__ == '__main__':
    main()
