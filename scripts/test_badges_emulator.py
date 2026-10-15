#!/usr/bin/env python3
"""Run badge integration checks only against an isolated local demo project."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--emulator-jar", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryFile() as log:
    process = subprocess.Popen(["java", "-jar", str(Path(args.emulator_jar).resolve()), "--host", "127.0.0.1", "--port", "8084", "--project_id", "demo-prono4-badges", "--single_project_mode"], stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(80):
            if process.poll() is not None:
                log.seek(0)
                raise RuntimeError(log.read().decode())
            try:
                with socket.create_connection(("127.0.0.1", 8084), timeout=.2):
                    break
            except OSError:
                time.sleep(.25)
        else:
            raise RuntimeError("Firestore emulator startup failed")
        env = dict(os.environ, FIRESTORE_EMULATOR_HOST="127.0.0.1:8084", GCLOUD_PROJECT="demo-prono4-badges")
        subprocess.run(["node", "--test", "test/firestore.integration.js"], cwd=root / "badge-functions", env=env, check=True)
    finally:
        process.terminate()
        try:
            process.wait(timeout=4)
        except subprocess.TimeoutExpired:
            process.kill()
