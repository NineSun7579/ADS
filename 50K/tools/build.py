"""Portable, fresh PDS build. No IP generation, programming or network access."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TOP = 'hdmi_ddr_ov5640_top'
ARCH = 'set_arch -family Logos -device PGL50H -speedgrade -6 -package FBG484\n'


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def audit():
    manifest = json.loads((ROOT / 'manifest.json').read_text(encoding='utf-8'))
    errors = []
    for name, expected in manifest['files'].items():
        path = ROOT / name
        if not path.is_file() or sha(path) != expected:
            errors.append('missing/changed: ' + name)
    project = (ROOT / 'nh50v10.pds').read_text(encoding='utf-8')
    for name in re.findall(r'\(_(?:file|ip|ip_source_item) "([^"]+)"', project):
        if not (ROOT / name).is_file():
            errors.append('project dependency: ' + name)
    source_files = []
    for idf in (ROOT / 'source').rglob('*.idf'):
        tree = ET.parse(idf)
        for item in tree.findall('.//file_list/source/file'):
            path = (idf.parent / item.attrib['pathname']).resolve()
            if not path.is_relative_to(ROOT) or not path.is_file():
                errors.append('IP source: ' + str(path))
            source_files.append(path)
    for path in list((ROOT / 'source').rglob('*')) + list((ROOT / 'constraints_c5').rglob('*')) + [ROOT / 'hdmi_in_mes50hp.fdc']:
        if path.suffix not in {'.v', '.vp', '.vh', '.idf', '.fdc'}:
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        # Do not mistake URL/comment text for a dependency.
        active = re.sub(r'/\*.*?\*/|//[^\n]*', '', text, flags=re.S)
        if re.search(r'[A-Za-z]:[/\\]', active):
            errors.append('absolute source dependency: ' + str(path))
        for name in re.findall(r'`include\s+"([^"]+)"', active):
            candidates = [path.parent / name, ROOT / name]
            # Vendor simulation scripts resolve includes from their simulation cwd.
            candidates.extend(parent / name for parent in path.parents if parent.is_relative_to(ROOT))
            if not any(candidate.is_file() for candidate in candidates):
                errors.append('include: ' + str(path) + ': ' + name)
        for name in re.findall(r'\$readmem[bh]\s*\(\s*"([^"]+)"', active):
            if not any(candidate.is_file() for candidate in [path.parent / name, ROOT / name]):
                errors.append('readmem: ' + str(path) + ': ' + name)
        for name in re.findall(r'^\s*(?:source|read_sdc)\s+["{]?([^"}\s]+)', active, re.M):
            if not any(candidate.is_file() for candidate in [path.parent / name, ROOT / name]):
                errors.append('constraint include: ' + str(path) + ': ' + name)
    result = {'pass': not errors, 'files_hashed': len(manifest['files']),
              'ip_source_entries': len(source_files), 'errors': errors,
              'parameterized_readmem': 'DDR distributed FIFO INIT_FILE defaults to NONE; instantiated with NONE. RAM IP INIT_EN=0/INIT_FILE=NONE; .dat and init_param.v retained.',
              'external_dependencies': ['PDS 2022.2-SP6.4 build146967, device/primitive libraries and valid tool licenses', 'Python 3.10+ standard library']}
    print(json.dumps(result, indent=2), flush=True)
    if errors:
        raise SystemExit('Dependency/integrity audit FAILED')
    return result


def discover(explicit):
    candidates = []
    for value in [explicit, os.environ.get('PDS_SHELL'), os.environ.get('PDS_HOME')]:
        if value:
            path = Path(value).expanduser()
            candidates.extend([path, path / 'bin/pds_shell.exe'])
    executable = shutil.which('pds_shell') or shutil.which('pds_shell.exe')
    if executable:
        candidates.append(Path(executable))
    for base in [Path('C:/pango'), Path('C:/Program Files/Pango'), Path('D:/pango')]:
        if base.is_dir():
            candidates.extend(sorted(base.glob('PDS*/bin/pds_shell.exe'), reverse=True))
    for path in candidates:
        if path.is_file() and path.name.lower() in {'pds_shell.exe', 'pds_shell'}:
            return path.resolve()
    raise SystemExit('PDS not found: use --pds <pds_shell.exe or installation root>, PDS_SHELL/PDS_HOME, or PATH')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pds')
    parser.add_argument('--out', type=Path, default=ROOT / 'build')
    parser.add_argument('--stage', choices=['audit', 'compile', 'map', 'all'], default='all')
    args = parser.parse_args()
    result = audit()
    if args.stage == 'audit':
        return
    pds = discover(args.pds)
    out = args.out.resolve()
    if out.exists():
        raise SystemExit('Output already exists; choose a NEW --out directory (never reuses stale databases): ' + str(out))
    if any(character in str(out) + str(ROOT) for character in '{}\n\r'):
        raise SystemExit('Tcl paths cannot contain braces/newlines')
    out.mkdir(parents=True)
    (out / 'audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    # Keep generated Tcl and PDS project inputs relative, even in the build tree.
    shutil.copytree(ROOT / 'source', out / 'source')
    shutil.copytree(ROOT / 'constraints_c5', out / 'constraints_c5')
    shutil.copy2(ROOT / 'hdmi_in_mes50hp.fdc', out)
    shutil.copy2(ROOT / 'nh50v10.pds', out)
    state = {'pds': str(pds), 'pid': os.getpid(), 'completed': [], 'status': 'running'}

    def save():
        (out / 'status.json').write_text(json.dumps(state, indent=2), encoding='utf-8')

    def run(name, body):
        tcl = out / (name + '.tcl')
        tcl.write_text(ARCH + body + '\nexit\n', encoding='utf-8', newline='\n')
        save()
        with (out / (name + '.log')).open('wb') as log:
            process = subprocess.Popen([str(pds), '-file', tcl.name, '-work_dir', str(out),
                                        '-project_name', 'nh50v10'], cwd=out, stdout=log, stderr=subprocess.STDOUT)
            state['child_pid'] = process.pid
            save()
            print(name, 'PID', process.pid, 'log', out / (name + '.log'), flush=True)
            code = process.wait()
        text = (out / (name + '.log')).read_text(encoding='utf-8', errors='replace')
        if code or re.search(r'^\s*E:|Program Error|FATAL', text, re.M):
            raise RuntimeError(name + ' failed, rc=' + str(code))
        state['completed'].append(name)
        save()

    try:
        project = (out / 'nh50v10.pds').read_text(encoding='utf-8')
        designs = re.findall(r'\(_file "(source/rtl/[^"/]+\.v)"', project)
        ips = re.findall(r'\(_ip "([^"]+)"', project)
        constraints = ['constraints_c5/0_ov5640_sfp480p_test.fdc', 'hdmi_in_mes50hp.fdc', 'constraints_c5/bounded_cdc.fdc']
        setup = ''.join('add_design {' + name + '}\n' for name in designs + ips)
        setup += ''.join('add_constraint {' + name + '}\n' for name in constraints)
        body = setup + 'compile -system_verilog -top_module ' + TOP + '\n'
        if args.stage in {'map', 'all'}:
            body += 'synthesize -ads -selected_syn_tool_opt 2\ndev_map\n'
        run('compile' if args.stage == 'compile' else 'map', body)
        if args.stage == 'all':
            run('pnr', 'add_constraint -physical -pcf {device_map/' + TOP + '.pcf}\n'
                'pnr -input_db_file {device_map/' + TOP + '_map.adf} -force_to_run -gplace_seed 1 '
                '-optimize_multi_corner_timing -fix_hold_violation_in_route TRUE -fix_hold_violation_threshold 0')
            database = out / 'place_route' / (TOP + '_pnr.adf')
            digest = sha(database)
            run('sta_full', 'report_timing -input_db_file {place_route/' + TOP + '_pnr.adf} -force_to_run '
                '-delay_type min_max -nworst 1 -max_path 15000 -input_pins TRUE -report_exception TRUE')
            report = out / 'report_timing' / (TOP + '.rtr')
            with (out / 'review_full.json').open('w', encoding='utf-8') as review:
                code = subprocess.call([sys.executable, str(ROOT / 'tools/review_timing.py'), str(report)], stdout=review)
            review = json.loads((out / 'review_full.json').read_text(encoding='utf-8'))
            if code or not review['pass'] or sha(database) != digest:
                raise RuntimeError('Timing gate failed or routed DB changed: NO bitstream generated')
            run('bitgen', 'gen_bit_stream -input_db_file {place_route/' + TOP + '_pnr.adf} -force_to_run -create_bit_file TRUE')
            if sha(database) != digest:
                raise RuntimeError('Routed DB changed during bitgen')
            bits = list((out / 'generate_bitstream').glob('*.sbit'))
            if not bits:
                raise RuntimeError('No SBIT produced')
            state['routed_sha256'] = digest
            state['bitstreams'] = {str(bit.relative_to(out)): sha(bit) for bit in bits}
        state['status'] = 'pass'
        save()
    except Exception as error:
        state['status'] = 'failed'
        state['error'] = str(error)
        save()
        raise


if __name__ == '__main__':
    main()
