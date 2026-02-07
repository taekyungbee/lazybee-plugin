#!/usr/bin/env python3
"""
INFRA.md 기반 자동 포트 할당
Usage: python3 auto-assign-port.py [backend|frontend|infra]
"""

import re
import sys
from pathlib import Path

INFRA_DOC_PATH = Path.home() / "projects" / "shared-docs" / "INFRA.md"

PORT_RANGES = {
    "backend": (10000, 10999),
    "frontend": (11000, 11999),
    "infra": (12000, 12999),
}

RESERVED_PORTS = {3000, 2223, 5432, 8880, 11434}


def get_used_ports():
    if not INFRA_DOC_PATH.exists():
        return set()
    content = INFRA_DOC_PATH.read_text(encoding="utf-8")
    ports = set()
    for match in re.finditer(r"\b(\d{4,5})\b", content):
        port = int(match.group(1))
        if 10000 <= port <= 12999:
            ports.add(port)
    return ports


def assign_port(project_type="backend"):
    used = get_used_ports()
    lo, hi = PORT_RANGES.get(project_type, PORT_RANGES["backend"])
    for port in range(lo, hi + 1):
        if port not in used and port not in RESERVED_PORTS:
            return port
    return hi + 1


if __name__ == "__main__":
    ptype = sys.argv[1] if len(sys.argv) > 1 else "backend"
    print(assign_port(ptype))
