"""Small fail-closed reviewer and delivery tests; no vendor invocation."""
from pathlib import Path
import importlib.util
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from review_timing import review, KINDS

def fixture():
    lines = ['Design Summary : All Constraints Met.', 'Slack : 0.1']
    for corner in ('Slow Corner', 'Fast Corner'):
        for kind in KINDS:
            lines.extend([kind + ' Summary(' + corner + '):', 'clk 0.1 0.0 0 1', '====='])
    return '\n'.join(lines)

class DeliveryTest(unittest.TestCase):
    def check_report(self, text):
        with tempfile.TemporaryDirectory(prefix='pds_review_') as directory:
            path = Path(directory) / 'report.rtr'
            path.write_text(text)
            return review(path)['pass']

    def test_valid(self):
        self.assertTrue(self.check_report(fixture()))

    def test_failures(self):
        for text in (fixture().replace('Slack : 0.1', 'Slack : -0.001'),
                     fixture().replace('clk 0.1 0.0 0 1', 'clk -0.1 -0.1 1 1', 1),
                     fixture().replace('Minimum Pulse Width Summary(Fast Corner):', 'Missing:'),
                     fixture().replace('All Constraints Met.', 'Constraints Violated.'),
                     fixture().replace('clk 0.1 0.0 0 1', 'clk nan 0 0 1', 1),
                     fixture() + '\nSlack : nan', fixture() + '\nSlack : -inf'):
            with self.subTest(text=text[-200:]):
                self.assertFalse(self.check_report(text))

    def test_manifest_and_no_old_database(self):
        spec = importlib.util.spec_from_file_location('delivery_build', ROOT / 'build.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertGreater(module.verify(), 700)
        self.assertIn('-gplace_seed 62', module.PNR_OPTIONS)
        self.assertIn('-max_ctrl_chain_length 8', module.PNR_OPTIONS)
        self.assertFalse(list((ROOT / 'source').rglob('*.adf')))
        self.assertFalse(list((ROOT / 'ipcore').rglob('*.adf')))

if __name__ == '__main__':
    unittest.main()
