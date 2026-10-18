import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_resources import assess, timing_stability


class ResourcePolicyTests(unittest.TestCase):
    def sample(self, second, idle=60, free=80):
        return {"elapsed_seconds": second, "cpu_idle_percent": idle, "memory_free_percent": free,
                "compiler_and_test_processes": [{"name": "ghc", "pid": 123, "rss_kib": 1000000}]}

    def test_concurrent_compilers_with_headroom_are_accepted(self):
        self.assertTrue(assess([self.sample(t) for t in range(20)], [])["accepted"])

    def test_sustained_cpu_saturation_is_rejected(self):
        self.assertFalse(assess([self.sample(t, idle=2) for t in range(20)], [])["accepted"])

    def test_sustained_memory_pressure_is_rejected(self):
        self.assertFalse(assess([self.sample(t, free=2) for t in range(20)], [])["accepted"])

    def test_short_burst_and_recovery_do_not_reject(self):
        rows = [self.sample(t, idle=0 if t % 10 < 5 else 50) for t in range(30)]
        self.assertTrue(assess(rows, [])["accepted"])

    def test_missing_or_failed_samples_cannot_pass(self):
        self.assertFalse(assess([], [])["accepted"])
        self.assertFalse(assess([self.sample(0)], ["failed"])["accepted"])

    def test_variable_timings_do_not_support_a_claim(self):
        self.assertFalse(timing_stability([1, 1, 1, 1, 2])["stable"])
        self.assertTrue(timing_stability([10, 11, 10, 11, 10])["stable"])


if __name__ == "__main__":
    unittest.main()
