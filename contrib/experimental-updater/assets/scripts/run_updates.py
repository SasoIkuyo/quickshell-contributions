#!/usr/bin/python3
"""Stream an interactive package manager as JSON. Passwords belong to polkit."""
import codecs
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import selectors
import shutil
import subprocess
import sys
import termios

ANSI = re.compile(r'\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))')


def emit(event, **values):
    print(json.dumps(dict(event=event, **values), ensure_ascii=False), flush=True)


def build_command():
    auth = str(Path(__file__).with_name('update_auth.py'))
    if shutil.which('paru'):
        return ['paru', '-Syu', '--sudo', auth, '--sudoflags', '', '--nosudoloop',
                '--noupgrademenu', '--review', '--color', 'never']
    return [auth, '/usr/bin/pacman', '-Syu', '--color', 'never']


def run(command):
    master, slave = pty.openpty()
    attrs = termios.tcgetattr(slave)
    attrs[3] &= ~termios.ECHO
    termios.tcsetattr(slave, termios.TCSANOW, attrs)
    env = dict(os.environ, LC_ALL='C', TERM='dumb', PAGER='/usr/bin/cat',
               PARU_PAGER='/usr/bin/cat', EDITOR='/usr/bin/cat', VISUAL='/usr/bin/cat')
    def attach_terminal():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    child = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave,
                             env=env, preexec_fn=attach_terminal)
    os.close(slave)
    decoder = codecs.getincrementaldecoder('utf-8')('replace')
    selector = selectors.DefaultSelector()
    selector.register(master, selectors.EVENT_READ, 'output')
    selector.register(sys.stdin.fileno(), selectors.EVENT_READ, 'input')
    input_buffer = b''
    emit('started')
    try:
        while True:
            for key, _ in selector.select(timeout=0.25):
                if key.data == 'input':
                    data = os.read(sys.stdin.fileno(), 4096)
                    if not data:
                        selector.unregister(sys.stdin.fileno())
                        continue
                    input_buffer += data
                    while b'\n' in input_buffer:
                        line, input_buffer = input_buffer.split(b'\n', 1)
                        try:
                            reply = json.loads(line).get('reply', '')
                            if isinstance(reply, str) and len(reply) <= 4096 and '\n' not in reply and '\r' not in reply:
                                os.write(master, (reply + '\n').encode())
                        except (ValueError, AttributeError):
                            pass
                else:
                    try:
                        data = os.read(master, 8192)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        data = b''
                    if not data:
                        return child.wait()
                    text = ANSI.sub('', decoder.decode(data)).replace('\r\n', '\n').replace('\r', '\n')
                    emit('output', text=text)
            if child.poll() is not None:
                # Drain remaining PTY output through the next read (EIO at EOF).
                continue
    finally:
        selector.close()
        os.close(master)


def main():
    try:
        code = run(build_command())
    except Exception as error:
        emit('output', text=f'\nNo se pudo ejecutar la actualización: {error}\n')
        code = 1
    emit('finished', code=code)
    return code


if __name__ == '__main__':
    sys.exit(main())
