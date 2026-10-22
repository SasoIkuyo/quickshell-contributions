#!/usr/bin/env python3
"""Exercise the actual visualiser clock with fake bars and a software renderer."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = (ROOT / 'modules/background/Visualiser.qml').read_text()
    start = source.index('                Timer {')
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        if source[end] == '{':
            depth += 1
        elif source[end] == '}':
            depth -= 1
        end += 1
    clock = source[start:end]
    qml = '''import QtQuick
import QtTest
Item {
    id: root
    width: 100
    height: 100
    property bool rendererGpu: false
    QtObject {
        id: bars
        property bool settled: false
        property int frames: 0
        property bool validDelta: true
        function advance(delta) {
            frames++;
            validDelta = validDelta && delta > 0 && delta <= 0.1;
        }
    }
    QtObject {
        id: dataCanvas
        property int uploads: 0
        function requestPaint() { uploads++; }
    }
    CLOCK
    TestCase {
        name: "VisualiserClock"
        when: windowShown
        function test_boundedClockAndGpuUploads() {
            bars.frames = 0;
            wait(600);
            verify(bars.frames >= 5 && bars.frames <= 25, "Clock stays near 30 fps");
            verify(bars.validDelta);
            compare(dataCanvas.uploads, 0, "CPU renderer must not upload a data texture");
            root.rendererGpu = true;
            wait(130);
            verify(dataCanvas.uploads > 0, "GPU renderer receives updated data");
            root.opacity = 0;
            const paused = bars.frames;
            wait(130);
            compare(bars.frames, paused, "Hidden visualiser stops advancing");
        }
    }
}
'''.replace('CLOCK', clock)
    runner = '/usr/lib/qt6/bin/qmltestrunner' if Path('/usr/lib/qt6/bin/qmltestrunner').exists() else shutil.which('qmltestrunner')
    if not runner:
        raise RuntimeError('Qt Quick Test runner is required')
    with tempfile.TemporaryDirectory() as directory:
        fixture = Path(directory) / 'tst_visualiser.qml'
        fixture.write_text(qml)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        return subprocess.run([runner, '-input', directory, '-o', '-,txt'], env=env, timeout=20).returncode


if __name__ == '__main__':
    raise SystemExit(main())
