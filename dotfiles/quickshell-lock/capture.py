"""Take bounded, private snapshots before handing control to the session locker."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time


def capture(directory):
    backgrounds = {}
    try:
        result = subprocess.run(
            ["niri", "msg", "--json", "outputs"],
            capture_output=True, text=True, check=True, timeout=0.5,
        )
        outputs = json.loads(result.stdout)
        names = [name for name, output in outputs.items() if output.get("current_mode") is not None]
    except (OSError, subprocess.SubprocessError, ValueError, AttributeError):
        return backgrounds

    pending = []
    deadline = time.monotonic() + 1
    for index, name in enumerate(names):
        path = directory / f"{index}.png"
        try:
            process = subprocess.Popen(
                ["grim", "-o", name, "-s", "0.5", str(path)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            pending.append((name, path, process))
        except OSError:
            continue

    for name, path, process in pending:
        try:
            status = process.wait(timeout=max(0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            status = -1
        if status == 0 and path.is_file() and path.stat().st_size:
            backgrounds[name] = path.as_uri()
        else:
            path.unlink(missing_ok=True)
    return backgrounds


if __name__ == "__main__":
    os.umask(0o077)
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "workstation-lock"
    # systemd owns this directory and removes it, including on crashes/timeouts.
    os.environ["WORKSTATION_LOCK_BACKGROUNDS"] = json.dumps(capture(directory))
    os.execv(sys.argv[1], [sys.argv[1], "-c", "workstation-lock"])
