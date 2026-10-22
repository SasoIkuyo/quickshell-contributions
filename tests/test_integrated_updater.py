import importlib.util, json, subprocess, sys, unittest
from pathlib import Path
from unittest.mock import patch
BASE = Path(__file__).resolve().parents[1] / 'contrib/experimental-updater/assets/scripts'

def load(name):
    spec = importlib.util.spec_from_file_location(name, BASE / (name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

class UpdateTest(unittest.TestCase):

    def test_auth(self):
        auth = load('update_auth')
        self.assertIsNone(auth.command_for(['-v']))
        self.assertEqual(auth.command_for(['--', '/usr/bin/pacman', '-Syu'])[:3], ['/usr/bin/pkexec', '--disable-internal-agent', '/usr/bin/pacman'])
        with self.assertRaises(ValueError):
            auth.command_for(['-u', 'another-user', 'true'])

    def test_keeps_review_and_confirmation(self):
        runner = load('run_updates')
        with patch.object(runner.shutil, 'which', return_value='/usr/bin/paru'):
            cmd = runner.build_command()
        self.assertIn('--review', cmd)
        self.assertNotIn('--noconfirm', cmd)
        self.assertNotIn('--skipreview', cmd)

    def test_live_output_and_reply(self):
        fake = 'import os;print("progress 25%",flush=True);answer=input("Proceed? [Y/n] ");print("answer="+answer,flush=True);print("tty="+str(os.isatty(0)),flush=True)'
        harness = f'import sys;sys.path.insert(0,{str(BASE)!r});import run_updates;sys.exit(run_updates.run([sys.executable,"-c",{fake!r}]))'
        result = subprocess.run([sys.executable, '-c', harness], input=json.dumps({'reply': 'y'}) + '\n', capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        events = [json.loads(line) for line in result.stdout.splitlines()]
        log = ''.join((e.get('text', '') for e in events))
        self.assertIn('25%', log)
        self.assertIn('answer=y', log)
        self.assertIn('tty=True', log)

    def test_failure_code(self):
        harness = f'import sys;sys.path.insert(0,{str(BASE)!r});import run_updates;sys.exit(run_updates.run([sys.executable,"-c","import sys;sys.exit(7)"]))'
        result = subprocess.run([sys.executable, '-c', harness], input='', capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 7)
if __name__ == '__main__':
    unittest.main()
