"""Source and preprocessed ARM build contract checks; does not run ADS."""
from pathlib import Path
import re
import shlex
import subprocess

root = Path(__file__).resolve().parent
viewer = root / 'host/viewer'
pipeline = (viewer / 'vision_pipeline.cpp').read_text()
assert 'fourFair.choose(ready)' in pipeline
assert 'if(i<0) return;' in pipeline
assert 'blackImage' not in pipeline and 'blackSequence' not in pipeline
main = (viewer / 'main-bev.cpp').read_text()
assert 'if(syntheticBlack) return;' in main
assert 'if(frame.syntheticBlack) { return;' in main
assert 'blackInput' not in main
assert main.index('ADS production rejects test/remote input') < main.index('QCoreApplication app(argc,argv);', main.index('static int runAds'))
assert 'static constexpr bool replaySignalPredictions=false' in (viewer / 'exact_ui.h').read_text()
build = root / 'build-arm'
variables = {}
for line in (build / 'Makefile').read_text().splitlines():
    match = re.match(r'^(CXX|CXXFLAGS|DEFINES|INCPATH)\s*=\s*(.*)$', line)
    if match:
        variables[match[1]] = shlex.split(match[2])
command = [part for part in variables['CXX'] + variables['CXXFLAGS'] + variables['DEFINES'] + variables['INCPATH'] if part != '$(DEFINES)']
preprocessed = subprocess.check_output(command + ['-E', '-P', str(viewer / 'main-bev.cpp')], cwd=build, text=True)
for forbidden in ('new perception_bird::ReplayInput', '/tmp/ads-replay-', 'local_video::',
                  'blackInput(', 'decoder.start("ffmpeg"', 'captures[i].open(path.toStdString())'):
    assert forbidden not in preprocessed, forbidden
assert 'ADS_PRODUCTION_LIVE_ONLY=1' in ' '.join(variables['DEFINES'])
probe = subprocess.run(variables['CXX'] + ['-x', 'c++', '-E', '-DADS_PRODUCTION_LIVE_ONLY=1',
    '-DADS_ENABLE_TEST_INPUTS=1', str(viewer / 'production_contract.h')], capture_output=True)
assert probe.returncode != 0 and b'forbids' in probe.stderr
header = subprocess.check_output(['readelf', '-h', str(build / 'ads-production-live')], text=True)
assert 'AArch64' in header
print('PASS: fresh-only fair dispatch; synthetic submission refused; replay/UDP/media/local-video/AvmSim absent from ARM preprocessed main; test-input macro cannot be enabled; linked ELF AArch64.')
