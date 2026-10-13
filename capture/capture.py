import glob
import os
import shutil
import signal
import subprocess
import sys
import time

INTERFACE = "lo" # feel free to change this to whatever interface you need to capture.
RAM_DIR = "/mnt/cap" # this is tmpfs. please make sure this is created via /etc/fstab
SD_DIR = "/home/ben/captures" # please update this to your home directory. folder will be created automatically if it does not exist.
FILE_SIZE_KB = 10240
POLL_SECONDS = 2

os.makedirs(SD_DIR, exist_ok=True)

tshark = subprocess.Popen([
    "tshark",
    "-i", INTERFACE,
    "-n",
    "-b", f"filesize:{FILE_SIZE_KB}",
    "-w", os.path.join(RAM_DIR, "cap.pcapng"),
])


def flush(include_active=False):
    files = sorted(glob.glob(os.path.join(RAM_DIR, "cap_*.pcapng")))
    if not include_active:
        files = files[:-1]
    for path in files:
        shutil.move(path, os.path.join(SD_DIR, os.path.basename(path)))


def shutdown(signum, frame):
    tshark.terminate()
    tshark.wait()
    flush(include_active=True)
    sys.exit(0)


signal.signal(signal.SIGINT, shutdown)
signal.signal(signal.SIGTERM, shutdown)

while tshark.poll() is None:
    flush()
    time.sleep(POLL_SECONDS)

flush(include_active=True)
sys.exit(tshark.returncode)
