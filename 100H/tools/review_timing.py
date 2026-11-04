"""Streaming, fail-closed PDS timing gate including five-field pulse-width rows."""
import json
import math
from pathlib import Path
import re
import sys

KINDS = ('Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width')
REQUIRED = {(kind, corner) for kind in KINDS for corner in ('Slow Corner', 'Fast Corner')}

def review(path):
    sections, failures, summaries = [], [], []
    current = None
    detailed = 0
    lines = 0
    section_re = re.compile(r'^\s*(Setup|Hold|Recovery|Removal|Minimum Pulse Width) Summary\(([^)]+)\):')
    slack_re = re.compile(r'\bSlack\b\s*(?:\([^)]*\))?\s*[:=]?\s*([-+]?\d+(?:\.\d*)?(?:[eE][-+]?\d+)?)', re.I)
    invalid_re = re.compile(r'\b(?:nan|inf|infinity)\b|\bviolat(?:ed|ion|ions)\b', re.I)
    with Path(path).open(encoding='utf-8', errors='replace') as stream:
        for lines, line in enumerate(stream, 1):
            if '\ufffd' in line:
                if len(failures) < 100:
                    failures.append({'line': lines, 'error': 'Undecodable report content'})
            if 'Design Summary' in line:
                match = re.search(r'Design Summary\s*:\s*(.*)', line)
                if match:
                    summaries.append(match.group(1).strip())
            if invalid_re.search(line) and len(failures) < 100:
                failures.append({'line': lines, 'error': line.strip()[:500]})
            match = slack_re.search(line)
            if match:
                detailed += 1
                value = float(match.group(1))
                if (not math.isfinite(value) or value < 0) and len(failures) < 100:
                    failures.append({'line': lines, 'error': 'Negative/nonfinite detailed slack', 'value': value})
            match = section_re.match(line)
            if match:
                current = {'kind': match.group(1), 'corner': match.group(2), 'rows': []}
                sections.append(current)
                continue
            if current is not None and '=====' in line:
                current = None
            if current is not None:
                fields = line.split()
                if len(fields) >= 5:
                    try:
                        slack, total = float(fields[-4]), float(fields[-3])
                        failing, endpoints = int(fields[-2]), int(fields[-1])
                    except ValueError:
                        continue
                    row = {'clocks': ' '.join(fields[:-4]), 'slack_ns': slack, 'total_negative_ns': total,
                           'failing_endpoints': failing, 'endpoints': endpoints}
                    current['rows'].append(row)
                    if not all(math.isfinite(value) for value in (slack, total)) or slack < 0 or total != 0 or failing != 0 or endpoints <= 0:
                        if len(failures) < 100:
                            failures.append({'line': lines, 'kind': current['kind'], 'corner': current['corner'], **row})
    present = {(section['kind'], section['corner']) for section in sections if section['rows']}
    passed = summaries == ['All Constraints Met.'] and present == REQUIRED and len(sections) == 10 and detailed > 0 and not failures
    return {'report': str(Path(path).resolve()), 'pass': passed, 'design_summaries': summaries,
            'lines_scanned': lines, 'detailed_slack_count': detailed,
            'missing_sections': sorted(REQUIRED - present), 'failures': failures, 'sections': sections}

if __name__ == '__main__':
    result = review(sys.argv[1])
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['pass'] else 1)
