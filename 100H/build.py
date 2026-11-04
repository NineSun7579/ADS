"""Portable clean source build; no GUI, IP regeneration, cached design or board access."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import traceback

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
from review_timing import review

ARCH = 'set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484\n'
PNR_OPTIONS = ('-force_to_run -gplace_seed 62 -slack_prior_in_global_router TRUE '
               '-logic_optimize_enable TRUE -optimize_multi_corner_timing -fix_hold_violation '
               '-fix_hold_violation_iterations 500 -fix_hold_violation_threshold 100 '
               '-fix_hold_violation_in_route TRUE -fix_hold_violation_threshold_for_clock_path_cross_srb 200 '
               '-fix_hold_violation_threshold_for_clk_tree 200 -max_hold_violated_paths_num 100000 '
               '-fast_router FALSE -max_ctrl_chain_length 8')

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

def save(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')

def verify():
    manifest = json.loads((ROOT / 'MANIFEST.json').read_text(encoding='utf-8'))
    for item in manifest['files']:
        path = (ROOT / item['path']).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file() or sha(path) != item['sha256']:
            raise RuntimeError('Manifest mismatch: ' + item['path'])
    project = ROOT / 'project/top.pds'
    for name in re.findall(r'\((?:_file|_ip|_ip_source_item) "([^"]+)"', project.read_text()):
        path = (project.parent / name).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise RuntimeError('External/missing project dependency: ' + name)
    return len(manifest['files'])

def find_pds(explicit):
    candidates = []
    for value in (explicit, os.environ.get('PDS_HOME'), os.environ.get('PDS_ROOT'), shutil.which('pds_shell.exe')):
        if value:
            path = Path(value)
            candidates.extend((path, path / 'bin/pds_shell.exe', path / 'pds_shell.exe'))
    for base in (Path('C:/pango'), Path('C:/Pango'), Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Pango'):
        if base.exists():
            candidates.extend(sorted(base.glob('PDS*/bin/pds_shell.exe'), reverse=True))
    for path in candidates:
        if path.is_file() and path.name.lower() == 'pds_shell.exe':
            return path.resolve()
    raise RuntimeError('PDS not found: use --pds C:/.../bin/pds_shell.exe or PDS_HOME')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pds', help='PDS installation directory or pds_shell.exe')
    parser.add_argument('--stage', choices=('compile', 'map', 'full'), default='full')
    parser.add_argument('--work', help='NEW output directory (must not exist)')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    count = verify()
    if args.verify_only:
        print('VERIFIED', count, 'pinned files; all project dependencies local')
        return 0
    pds = find_pds(args.pds)
    version = subprocess.run([str(pds), '-help'], capture_output=True, text=True)
    version_text = version.stdout + version.stderr
    if version.returncode or '2022.2-SP6.4 build 146967' not in version_text:
        raise RuntimeError('Require tested PDS 2022.2-SP6.4 build 146967; found: ' + version_text[:500])
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    work = Path(args.work).resolve() if args.work else ROOT / 'build' / stamp
    if work.exists():
        raise RuntimeError('Refuse reused output directory: ' + str(work))
    reserve = 8 * 1024**3
    required = reserve + (3 * 1024**3 if args.stage == 'full' else 256 * 1024**2)
    if shutil.disk_usage(ROOT).free < required:
        raise RuntimeError('Disk preflight: need ' + str(required) + ' free bytes; no cleanup authorized')
    work.mkdir(parents=True)
    state = dict(pid=os.getpid(), status='RUNNING', stage=args.stage, work=str(work),
                 pds=str(pds), pds_sha256=sha(pds), started=datetime.datetime.now().isoformat(),
                 reference_bitstream_sha256='3ccdaa213355d9cf1955701993d7e1a3b8826f48fde04d545855ab3712abf50f',
                 bitstream_generated=False, board_access=False, stages={})
    save(work / 'result.json', state)
    (work / 'PID.txt').write_text(str(os.getpid()))
    (work / 'tool_version.txt').write_text(version_text)
    # A work directory can be anywhere: rewrite ONLY source/IP path prefixes.
    project = (ROOT / 'project/top.pds').read_text()
    project = project.replace('../source/', (ROOT / 'source').as_posix() + '/')
    project = project.replace('../ipcore/', (ROOT / 'ipcore').as_posix() + '/')
    (work / 'project.pds').write_text(project, encoding='utf-8')
    print('BUILD_PID', os.getpid(), 'WORK', work, flush=True)

    def stage(name, body=None):
        verify()
        if shutil.disk_usage(work).free < reserve + (3 * 1024**3 if name == 'sta_full' else 64 * 1024**2):
            raise RuntimeError('Disk reserve insufficient before ' + name)
        if body:
            script = work / (name + '.tcl')
            script.write_text(ARCH + body + '\nexit\n')
            command = [str(pds), '-file', str(script), '-work_dir', str(work), '-project_name', 'top']
        else:
            command = [str(pds), '-project', str(work / 'project.pds'), '-run', name, '-work_dir', str(work)]
        log = work / (name + '.stdout.log')
        with log.open('xb') as stream:
            process = subprocess.Popen(command, cwd=work, stdout=stream, stderr=subprocess.STDOUT)
            state['stages'][name] = dict(pid=process.pid, command=command, status='RUNNING')
            save(work / 'result.json', state)
            returncode = process.wait()
        errors = []
        with log.open(errors='replace') as stream:
            for line in stream:
                if re.search(r'^\s*E:|Program Error|FATAL', line) and len(errors) < 100:
                    errors.append(line.strip())
        state['stages'][name].update(returncode=returncode, errors=errors, log_sha256=sha(log), status='FINISHED')
        save(work / 'result.json', state)
        if returncode or errors:
            raise RuntimeError(name + ' failed; inspect ' + str(log))
        verify()
        print(name, 'PASS', flush=True)

    try:
        stage('compile')
        if not (work / 'compile/top_comp.adf').is_file():
            raise RuntimeError('Compile output missing')
        if args.stage != 'compile':
            stage('synthesize')
            stage('dev_map')
            state['fresh_mapped_sha256'] = sha(work / 'device_map/top_map.adf')
            state['fresh_pcf_sha256'] = sha(work / 'device_map/top.pcf')
        if args.stage == 'full':
            stage('pnr', 'add_constraint -physical -pcf {' + (work / 'device_map/top.pcf').as_posix() + '}\n'
                  'pnr -input_db_file {' + (work / 'device_map/top_map.adf').as_posix() + '} ' + PNR_OPTIONS)
            routed = work / 'place_route/top_pnr.adf'
            routed_hash = sha(routed)
            stage('sta_full', 'report_timing -input_db_file {' + routed.as_posix() + '} -force_to_run '
                  '-delay_type min_max -nworst 1 -max_path 15000 -input_pins TRUE -report_exception TRUE')
            report = work / 'report_timing/top.rtr'
            reviewed = review(report)
            save(work / 'timing_review.json', reviewed)
            state['timing_pass'] = reviewed['pass']
            state['timing_report_sha256'] = sha(report)
            save(work / 'result.json', state)
            if not reviewed['pass']:
                raise RuntimeError('Full 10-section/pulse/detailed-slack timing review failed: bitgen prohibited')
            if sha(routed) != routed_hash:
                raise RuntimeError('Routed database changed after STA')
            stage('bitgen', 'gen_bit_stream -input_db_file {' + routed.as_posix() + '} -force_to_run -create_bit_file TRUE')
            bitstream = work / 'generate_bitstream/top.sbit'
            if not bitstream.is_file() or bitstream.stat().st_size == 0:
                raise RuntimeError('Bitstream missing or empty')
            if sha(routed) != routed_hash:
                raise RuntimeError('Routed database changed during bitgen')
            state.update(bitstream_generated=True, bitstream=str(bitstream), bitstream_sha256=sha(bitstream), routed_sha256=routed_hash)
        state['status'] = 'PASS_' + args.stage.upper()
        return 0
    except Exception as error:
        state.update(status='FAILED_CLOSED', error=str(error), traceback=traceback.format_exc())
        print(state['error'], file=sys.stderr, flush=True)
        return 1
    finally:
        state['finished'] = datetime.datetime.now().isoformat()
        save(work / 'result.json', state)

if __name__ == '__main__':
    raise SystemExit(main())
