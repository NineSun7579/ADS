"""Small adversarial signoff tests; no FPGA tools needed."""
from pathlib import Path
import tempfile
import unittest
from review_timing import KINDS, review


def fixture():
    text = 'Design Summary : All Constraints Met.\n'
    for kind in KINDS:
        for corner in ['Slow Corner', 'Fast Corner']:
            clocks = 'clk' if kind == 'Minimum Pulse Width' else 'clk clk'
            text += f'{kind} Summary({corner}):\n{clocks} 0.100 0.000 0 10\n=====\n'
    return text


class TimingTests(unittest.TestCase):
    def check(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.rtr'
            path.write_text(text)
            return review(path)['pass']

    def test_good(self):
        self.assertTrue(self.check(fixture()))

    def test_single_clock_pulse_failure(self):
        self.assertFalse(self.check(fixture().replace('clk 0.100', 'clk -0.001', 1)))

    def test_missing_section(self):
        self.assertFalse(self.check(fixture().replace('Removal Summary(Fast Corner):', 'omitted:')))

    def test_detail_violation(self):
        self.assertFalse(self.check(fixture() + 'Slack (VIOLATED) : -0.001\n'))

    def test_total_negative(self):
        self.assertFalse(self.check(fixture().replace('0.000 0 10', '-0.010 0 10', 1)))

    def test_duplicate(self):
        self.assertFalse(self.check(fixture() + 'Setup Summary(Slow Corner):\nclk clk 1.0 0.0 0 1\n=====\n'))

    def test_nan(self):
        self.assertFalse(self.check(fixture().replace('0.100', 'nan', 1)))

    def test_truncated(self):
        self.assertFalse(self.check('Design Summary : All Constraints Met.\n'))


if __name__ == '__main__':
    unittest.main()
