"""Check recovery decisions without interrupting the desktop or screen sharing."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "portal_healthcheck", Path(__file__).resolve().parents[1] / "scripts/portal-healthcheck.py")
portal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portal)


class PortalHealthcheckTests(unittest.TestCase):
    def check(self, states, replies=(False, False), clock=(0, 5, 5, 10)):
        with mock.patch.object(portal, "snapshot", side_effect=states), \
             mock.patch.object(portal, "responsive", side_effect=replies), \
             mock.patch.object(portal.time, "monotonic", side_effect=clock), \
             mock.patch.object(portal.subprocess, "run") as command:
            command.return_value.returncode = 0
            result = portal.check()
            return result, command.call_args_list

    def test_recovers_sustained_spin_after_two_timeouts(self):
        result, calls = self.check([("a", 0), ("a", 5_000_000_000), ("a", 10_000_000_000)])
        self.assertEqual(result, 0)
        self.assertEqual(calls, [mock.call(
            ["systemctl", "--user", "try-restart", portal.UNIT], timeout=45)])

    def test_responsive_portal_is_left_running(self):
        self.assertEqual(self.check([("a", 0)], replies=(True,)), (0, []))

    def test_second_probe_can_recover_without_restart(self):
        self.assertEqual(self.check(
            [("a", 0), ("a", 5_000_000_000)], replies=(False, True)), (0, []))

    def test_waiting_picker_does_not_trigger_recovery(self):
        self.assertEqual(self.check([("a", 0), ("a", 10_000_000)]), (0, []))

    def test_cpu_must_remain_high_during_both_probes(self):
        self.assertEqual(self.check(
            [("a", 0), ("a", 5_000_000_000), ("a", 5_010_000_000)]), (0, []))

    def test_service_stops_or_restarts_during_probe(self):
        for after in (None, ("b", 5_000_000_000)):
            with self.subTest(after=after):
                self.assertEqual(self.check([("a", 0), after]), (0, []))

    def test_inactive_portal_is_not_started(self):
        self.assertEqual(self.check([None], replies=(), clock=()), (0, []))

    def test_immediate_bus_failure_is_not_a_hang(self):
        self.assertEqual(self.check(
            [("a", 0), ("a", 5_000_000_000)], clock=(0, 0.1)), (0, []))

    def test_unavailable_cpu_accounting_is_not_a_hang(self):
        output = "ActiveState=active\nSubState=running\nInvocationID=a\nCPUUsageNSec=[not set]\n"
        with mock.patch.object(portal.subprocess, "run", return_value=
                               subprocess.CompletedProcess([], 0, output)):
            self.assertIsNone(portal.snapshot())

    def test_probe_never_activates_a_stopped_service(self):
        with mock.patch.object(portal.subprocess, "run", return_value=
                               subprocess.CompletedProcess([], 0)) as command:
            self.assertTrue(portal.responsive())
            self.assertIn("--auto-start=no", command.call_args.args[0])
            self.assertIn("--timeout=5s", command.call_args.args[0])

    def test_probe_process_timeout_is_handled(self):
        with mock.patch.object(portal.subprocess, "run", side_effect=
                               subprocess.TimeoutExpired("busctl", 6)):
            self.assertFalse(portal.responsive())


if __name__ == "__main__":
    unittest.main()
