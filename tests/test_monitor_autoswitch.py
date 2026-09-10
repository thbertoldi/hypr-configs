"""Exercise dock recovery without touching the live compositor."""
import json
import fcntl
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/monitor-autoswitch.sh"


def monitor(name, width=1920, height=1080, disabled=False, dpms=True):
    return dict(name=name, width=width, height=height, disabled=disabled,
                dpmsStatus=dpms)


class MonitorAutoswitchTests(unittest.TestCase):
    def run_script(self, monitors, query_failure=False, next_monitors=(), lock_held=False,
                   after_reload=None, ignore_eval=False, session_active=True,
                   cooldown=False, wake=False, reload_failure=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "monitors.json").write_text(json.dumps([monitors, *next_monitors]))
            (root / "control.json").write_text(json.dumps(dict(
                after_reload=after_reload, ignore_eval=ignore_eval,
                session_active=session_active, reload_failure=reload_failure)))
            if cooldown:
                (root / "hypr-monitor-recovery.at").write_text(str(int(time.time())) + "\n")
            fake = root / "hyprctl"
            fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ["MONITOR_TEST_DIR"])
args = sys.argv[1:]
control = json.loads((root / "control.json").read_text())
forced = root / "forced.json"
current = root / "current.json"
if args == ["monitors", "all", "-j"]:
    if os.environ["MONITOR_TEST_FAIL"] == "1":
        sys.exit(1)
    counter = root / "query-count"
    index = int(counter.read_text()) if counter.exists() else 0
    snapshots = json.loads((root / "monitors.json").read_text())
    state = json.loads(forced.read_text()) if forced.exists() else snapshots[min(index, len(snapshots) - 1)]
    print(json.dumps(state))
    current.write_text(json.dumps(state))
    counter.write_text(str(index + 1))
else:
    with (root / "calls.jsonl").open("a") as stream:
        stream.write(json.dumps(args) + "\\n")
    if args == ["reload", "config-only"]:
        if control["reload_failure"]:
            sys.exit(1)
        if control["after_reload"] is not None:
            forced.write_text(json.dumps(control["after_reload"]))
    elif args[0] == "eval":
        if not control["ignore_eval"]:
            state = json.loads(current.read_text())
            for output in state:
                if output["name"] == "eDP-1":
                    output["disabled"] = "disabled = true" in args[1]
                    if not output["disabled"]:
                        output.update(width=1920, height=1080)
            forced.write_text(json.dumps(state))
    elif args[0] != "dispatch":
        sys.exit("Unexpected compositor command")
    print("ok")
''')
            fake.chmod(0o755)
            loginctl = root / "loginctl"
            loginctl.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ["MONITOR_TEST_DIR"])
if sys.argv[1] == "show-user":
    print("3")
else:
    control = json.loads((root / "control.json").read_text())
    print("yes" if control["session_active"] else "no")
''')
            loginctl.chmod(0o755)
            # Advance through snapshots without delaying the test suite.
            sleeper = root / "sleep"
            sleeper.write_text("#!/bin/sh\nexit 0\n")
            sleeper.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       XDG_RUNTIME_DIR=str(root),
                       MONITOR_TEST_DIR=str(root),
                       MONITOR_TEST_FAIL="1" if query_failure else "0")
            with (root / "hypr-monitor-autoswitch.lock").open("w") as lock:
                if lock_held:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                result = subprocess.run([str(SCRIPT), *(["--wake"] if wake else [])], env=env, capture_output=True,
                                        text=True, timeout=5)
            log = root / "calls.jsonl"
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_unusable_external_outputs_enable_laptop(self):
        panel = monitor("eDP-1", 0, 0, disabled=True)
        cases = [[], [monitor("FALLBACK")], [monitor("HDMI-A-1", 0, 0)],
                 [monitor("DP-1", disabled=True)],
                 [monitor("FALLBACK"), monitor("HDMI-A-1", 0, 0)]]
        for outputs in cases:
            with self.subTest(outputs=outputs):
                result, calls = self.run_script([panel, *outputs])
                self.assertEqual(result.returncode, 0, result.stderr)
                updates = [call for call in calls if call[0] == "eval"]
                self.assertEqual(len(updates), 1)
                self.assertIn('output = "eDP-1"', updates[0][1])
                self.assertIn("disabled = false", updates[0][1])
                self.assertIn('mode = "preferred"', updates[0][1])

    def test_zero_sized_hdmi_is_verified_after_configuration_reload(self):
        panel = monitor("eDP-1", disabled=True)
        result, calls = self.run_script(
            [panel, monitor("HDMI-A-1", 0, 0)],
            after_reload=[panel, monitor("HDMI-A-1", 3440, 1440)],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [["reload", "config-only"]])
        self.assertIn("External display recovered", result.stderr)

    def test_successful_reply_without_a_working_panel_is_not_success(self):
        result, calls = self.run_script([monitor("eDP-1", disabled=True)], ignore_eval=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls.count(["reload", "config-only"]), 1)
        self.assertEqual(len([call for call in calls if call[0] == "eval"]), 2)
        self.assertIn("did not produce a usable output", result.stderr)

    def test_panel_is_retried_after_stale_configuration_is_cleared(self):
        panel = monitor("eDP-1", disabled=True)
        result, calls = self.run_script([panel], ignore_eval=True,
                                         after_reload=[monitor("eDP-1")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[0] for call in calls], ["eval", "reload"])

    def test_failed_reload_can_still_fall_back_to_laptop(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True), monitor("HDMI-A-1", 0, 0)],
            reload_failure=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[0] for call in calls], ["reload", "eval"])

    def test_repeated_failure_is_rate_limited(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True), monitor("HDMI-A-1", 0, 0)],
            cooldown=True, ignore_eval=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(["reload", "config-only"], calls)
        self.assertEqual(len(calls), 1)

    def test_inactive_graphical_session_is_left_alone(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True), monitor("HDMI-A-1", 0, 0)],
            session_active=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_zero_sized_sleeping_display_is_not_woken_by_hotplug(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True), monitor("HDMI-A-1", 0, 0, dpms=False)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_wake_powers_on_and_recovers_without_a_hotplug_event(self):
        panel = monitor("eDP-1", disabled=True)
        result, calls = self.run_script(
            [panel, monitor("HDMI-A-1", 0, 0)], wake=True,
            after_reload=[panel, monitor("HDMI-A-1", 3440, 1440)],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[0] for call in calls], ["dispatch", "reload"])
        self.assertIn('action = "enable"', calls[0][1])

    def test_invalid_snapshot_after_reload_cannot_trigger_panel_changes(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True), monitor("HDMI-A-1", 0, 0)],
            after_reload={"error": "unavailable"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [["reload", "config-only"]])

    def test_usable_external_disables_laptop_even_when_dpms_off(self):
        for name, dpms in [("HDMI-A-1", True), ("DP-2", False)]:
            with self.subTest(name=name, dpms=dpms):
                result, calls = self.run_script([
                    monitor("eDP-1"), monitor(name, dpms=dpms)])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 1)
                self.assertEqual(calls[0][0], "eval")
                self.assertIn('output = "eDP-1"', calls[0][1])
                self.assertIn("disabled = true", calls[0][1])

    def test_hdmi_returning_during_wake_does_not_switch_to_laptop(self):
        panel = monitor("eDP-1", disabled=True)
        result, calls = self.run_script(
            [panel, monitor("FALLBACK")],
            next_monitors=[
                [panel, monitor("HDMI-A-1", 0, 0)],
                [panel, monitor("HDMI-A-1")],
            ],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_laptop_enabled_while_waiting_is_not_reconfigured(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True)],
            next_monitors=[[monitor("eDP-1")]],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_invalid_snapshot_during_wake_does_not_change_displays(self):
        result, calls = self.run_script(
            [monitor("eDP-1", disabled=True)],
            next_monitors=[{"error": "unavailable"}],
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_simultaneous_lid_event_does_not_race_the_listener(self):
        result, calls = self.run_script(
            [monitor("eDP-1"), monitor("HDMI-A-1")], lock_held=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_external_lost_during_docking_keeps_working_laptop(self):
        result, calls = self.run_script(
            [monitor("eDP-1"), monitor("HDMI-A-1")],
            next_monitors=[[monitor("eDP-1")]],
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_stable_layouts_and_missing_panel_need_no_changes(self):
        cases = [[monitor("eDP-1")], [monitor("HDMI-A-1")],
                 [monitor("eDP-1", 0, 0, disabled=True), monitor("HDMI-A-1")]]
        for outputs in cases:
            with self.subTest(outputs=outputs):
                result, calls = self.run_script(outputs)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls, [])

    def test_failed_query_does_not_change_displays(self):
        result, calls = self.run_script([], query_failure=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_invalid_response_does_not_change_displays(self):
        result, calls = self.run_script({"error": "unavailable"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
