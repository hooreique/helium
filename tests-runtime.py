import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

args = ['argument with spaces', '', 'literal\'"$()`']
children = []


def wait_for(test):
    for _ in range(300):
        if test():
            return
        time.sleep(.02)
    raise AssertionError('timed out')


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    runtime = root / 'runtime'
    runtime.mkdir()

    def env(name, **extra):
        return dict(os.environ, XDG_RUNTIME_DIR=str(runtime),
                    BROWSER_LOG=str(root / (name + '.args')),
                    PROXY_LOG=str(root / (name + '.proxy')), **extra)

    def run(command, name, **extra):
        return subprocess.run([os.environ[command], 'url with spaces', '--incognito'],
                              env=env(name, **extra), timeout=10)

    def launch(command, name):
        child = subprocess.Popen([os.environ[command]], env=env(
            name, BROWSER_HOLD=str(root / ('release-' + name))))
        children.append(child)
        wait_for(lambda: (root / (name + '.args')).exists())
        return child

    try:
        assert run('DIRECT', 'direct').returncode == 0
        assert json.loads((root / 'direct.args').read_text()) == args + ['url with spaces', '--incognito']
        assert not (root / 'direct.proxy').exists()
        assert run('HELIUM', 'normal').returncode == 0
        assert json.loads((root / 'normal.args').read_text()) == args + [
            '--proxy-server=http://127.0.0.1:48202', 'url with spaces', '--incognito']
        assert not alive(int((root / 'normal.proxy').read_text()))
        assert (runtime / 'spoofdpium-48202.lock').exists()

        owner = launch('HELIUM', 'owner')
        assert run('HELIUM', 'join').returncode == 0
        assert not (root / 'join.proxy').exists()
        chromium = launch('CHROMIUM', 'chromium')
        helium_pid = int((root / 'owner.proxy').read_text())
        chromium_pid = int((root / 'chromium.proxy').read_text())
        assert helium_pid != chromium_pid
        assert (runtime / 'spoofdpium-48201.lock').exists()
        (root / 'release-owner').touch()
        assert owner.wait(timeout=5) == 0
        assert not alive(helium_pid)
        assert alive(chromium_pid)
        chromium.terminate()
        assert chromium.wait(timeout=5) == 143
        assert not alive(chromium_pid)

        assert run('HELIUM', 'failed', PROXY_FAIL='1').returncode != 0
        assert not (root / 'failed.args').exists()
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 48202))
            listener.listen()
            assert run('HELIUM', 'collision').returncode != 0
            assert not (root / 'collision.args').exists()
            assert not (root / 'collision.proxy').exists()

        assert run('CUSTOM', 'custom').returncode == 0
        assert json.loads((root / 'custom.args').read_text()) == [
            '--user-data-dir=/test/config/net.imput.helium',
            '--proxy-server=http://127.0.0.1:49202', 'url with spaces', '--incognito']
        for key in ['HELIUM', 'DIRECT', 'CUSTOM']:
            executable = Path(os.environ[key])
            desktop = executable.parent.parent / 'share/applications/helium.desktop'
            lines = [line for line in desktop.read_text().splitlines() if line.startswith('Exec=')]
            assert len(lines) == 3
            assert all(line.startswith('Exec=' + str(executable)) for line in lines)
            assert '--new-window' in lines[1] and '%U' in lines[1]
            assert '--incognito %U' in lines[2]
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=5)
