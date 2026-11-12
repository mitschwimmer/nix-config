"""Snapshot failure must never prevent launching an opaque session lock."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "capture", Path(__file__).parents[1] / "dotfiles/quickshell-lock/capture.py"
)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureTests(unittest.TestCase):
    def test_missing_compositor_and_invalid_json_use_black(self):
        for outcome in [FileNotFoundError(), subprocess.TimeoutExpired("niri", 0.5),
                        subprocess.CompletedProcess([], 0, "invalid")]:
            with self.subTest(outcome=outcome), tempfile.TemporaryDirectory() as tmp:
                with patch.object(capture.subprocess, "run") as run:
                    if isinstance(outcome, Exception):
                        run.side_effect = outcome
                    else:
                        run.return_value = outcome
                    self.assertEqual(capture.capture(Path(tmp)), {})

    def test_outputs_capture_in_parallel_and_failed_files_are_removed(self):
        outputs = {"DP-1": {"current_mode": 0}, "DP-2": {"current_mode": 0},
                   "disabled": {"current_mode": None}, "eDP-1": {"current_mode": 1}}
        started = []

        class Process:
            def __init__(self, command, **kwargs):
                self.name = command[2]
                self.path = Path(command[-1])
                self.path.write_bytes(b"fake PNG")
                self.killed = False
                started.append(self.name)

            def wait(self, timeout=None):
                # Every output must start before we wait for the first one.
                self_check.assertEqual(started, ["DP-1", "DP-2", "eDP-1"])
                if self.name == "eDP-1" and not self.killed:
                    raise subprocess.TimeoutExpired("grim", timeout)
                return 1 if self.name == "DP-2" else 0

            def kill(self):
                self.killed = True

        self_check = self
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            with patch.object(capture.subprocess, "run", return_value=
                              subprocess.CompletedProcess([], 0, json.dumps(outputs))), \
                 patch.object(capture.subprocess, "Popen", Process):
                self.assertEqual(capture.capture(directory), {"DP-1": (directory / "0.png").as_uri()})
                self.assertEqual([p.name for p in directory.iterdir()], ["0.png"])

    def test_missing_capture_tool_uses_black(self):
        result = subprocess.CompletedProcess([], 0, '{"DP-1": {"current_mode": 0}}')
        with tempfile.TemporaryDirectory() as tmp, \
             patch.object(capture.subprocess, "run", return_value=result), \
             patch.object(capture.subprocess, "Popen", side_effect=FileNotFoundError()):
            self.assertEqual(capture.capture(Path(tmp)), {})


if __name__ == "__main__":
    unittest.main()
