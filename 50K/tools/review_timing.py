"""Streaming, fail-closed ten-section min/max timing signoff (incl. pulse width)."""
import json
import math
from pathlib import Path
import re
import sys

KINDS = ['Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width']
REQUIRED = {(kind, corner) for kind in KINDS for corner in ['Slow Corner', 'Fast Corner']}
HEADER = re.compile(r'^(Setup|Hold|Recovery|Removal|Minimum Pulse Width) Summary\(([^)]+)\):')


def review(path):
    sections = []
    failures = []
    summary = None
    current = None
    context = {}
    with path.open(encoding='utf-8', errors='replace') as stream:
        for number, line in enumerate(stream, 1):
            banner = re.search(r'Design Summary\s*:\s*([^\r\n]+)', line)
            if banner:
                summary = banner.group(1).strip()
            match = HEADER.match(line)
            if match:
                current = {'kind': match[1], 'corner': match[2], 'rows': []}
                sections.append(current)
                continue
            if current and line.startswith('====='):
                current = None
            if current:
                values = line.split()
                minimum = 5 if current['kind'] == 'Minimum Pulse Width' else 6
                if len(values) >= minimum:
                    try:
                        slack, total = float(values[-4]), float(values[-3])
                        failing, endpoints = int(values[-2]), int(values[-1])
                    except ValueError:
                        # A numeric-looking but unparseable data row is not silently discarded.
                        if re.search(r'\b(?:nan|inf)\b', line, re.I):
                            failures.append({'line': number, 'error': 'invalid numeric row'})
                        continue
                    row = {'clocks': ' '.join(values[:-4]), 'slack_ns': slack,
                           'total_negative_ns': total, 'failing_endpoints': failing, 'endpoints': endpoints}
                    current['rows'].append(row)
                    if not math.isfinite(slack) or not math.isfinite(total) or slack < 0 or total != 0 or failing != 0 or endpoints <= 0:
                        failures.append({'kind': current['kind'], 'corner': current['corner'], **row})
            field = re.match(r'\s*(Startpoint|Endpoint|Path Group|Path Type|Timing Exception)\s*:\s*(.*)', line)
            if field:
                if field[1] == 'Startpoint':
                    context = {}
                context[field[1]] = field[2].strip()
            if re.search(r'\bSlack\s*\(VIOLATED\)', line, re.I):
                failures.append({'line': number, 'verdict': line.strip(), **context})
    present = {(section['kind'], section['corner']) for section in sections if section['rows']}
    missing = sorted(REQUIRED - present)
    duplicates = len(sections) != len({(section['kind'], section['corner']) for section in sections})
    passed = summary == 'All Constraints Met.' and not missing and not failures and not duplicates and len(sections) == 10
    return {'report': str(path), 'summary': summary or 'MISSING', 'pass': passed,
            'missing_sections': missing, 'duplicate_sections': duplicates, 'failures': failures, 'sections': sections}


if __name__ == '__main__':
    result = review(Path(sys.argv[1]))
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['pass'] else 1)
