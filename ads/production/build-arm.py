"""Run only inside epsilon buildbox, with production source mounted in /work."""
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
build = root / 'build-arm'
build.mkdir(exist_ok=True)
env = os.environ.copy()
env['PKG_CONFIG_SYSROOT_DIR'] = '/work/sysroot'
env['PKG_CONFIG_LIBDIR'] = '/work/sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:/work/sysroot/usr/share/pkgconfig'
env.pop('PKG_CONFIG_PATH', None)
flags = '-O2 -g0 --sysroot=/work/sysroot'
subprocess.run(['qmake', '-spec', 'linux-aarch64-gnu-g++',
    str(root / 'host/viewer/ads-production.pro'),
    'QMAKE_CXXFLAGS_RELEASE=' + flags, 'QMAKE_CFLAGS_RELEASE=' + flags,
    'QMAKE_LFLAGS+=--sysroot=/work/sysroot -Wl,-rpath-link,/work/sysroot/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/work/sysroot/usr/lib',
    'LIBS+=-L/work/sysroot/usr/lib -L/work/sysroot/usr/lib/aarch64-linux-gnu'],
    cwd=build, env=env, check=True)
makefile = build / 'Makefile'
text = makefile.read_text()
text = text.replace('/usr/include/x86_64-linux-gnu/qt5', '/work/sysroot/usr/include/aarch64-linux-gnu/qt5')
text = text.replace('/usr/lib/x86_64-linux-gnu/libQt5', '/work/sysroot/usr/lib/aarch64-linux-gnu/libQt5')
text = text.replace('/usr/lib/x86_64-linux-gnu/libGL.so', '/work/sysroot/usr/lib/aarch64-linux-gnu/libGL.so')
makefile.write_text(text)
subprocess.run(['make', '-j6'], cwd=build, env=env, check=True)
