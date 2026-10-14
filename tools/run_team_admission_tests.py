#!/usr/bin/env python3
"""Start a local demo emulator and run admission checks in the same process namespace."""
from pathlib import Path
import argparse,subprocess,socket,time,tempfile

parser=argparse.ArgumentParser()
parser.add_argument('--emulator-jar',required=True)
parser.add_argument('--rules',default='firestore-admission-proposed.rules')
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryFile() as log:
    process=subprocess.Popen(['java','-jar',str(Path(args.emulator_jar).resolve()),'--host','127.0.0.1','--port','8081','--project_id','demo-prono4','--single_project_mode','--rules',str(root/args.rules)],stdout=log,stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                log.seek(0)
                raise RuntimeError(log.read().decode())
            try:
                with socket.create_connection(('127.0.0.1',8081),timeout=.2):break
            except OSError:time.sleep(.25)
        else:raise RuntimeError('Emulator startup failed')
        script=(root/'tools/test_team_admission_rules.py').read_text().replace('127.0.0.1:8080','127.0.0.1:8081')
        exec(compile(script,'test_team_admission_rules.py','exec'))
    finally:
        process.terminate()
        try:process.wait(timeout=4)
        except subprocess.TimeoutExpired:process.kill()
