#!/usr/bin/env python3
"""
INFRA.md에 프로젝트 정보 추가
Usage: python3 update-infra.py <project-name> <project-type> <port> [--db <database_url>]
"""

import re
import subprocess
import sys
from pathlib import Path

INFRA_DOC_PATH = Path.home() / "projects" / "shared-docs" / "INFRA.md"


def update_infra(project_name, project_type, port, database_url=None):
    if not INFRA_DOC_PATH.exists():
        print(f"ERROR: {INFRA_DOC_PATH} not found")
        sys.exit(1)

    content = INFRA_DOC_PATH.read_text(encoding="utf-8")

    # 이미 존재하는지 확인
    if f"| {project_name} |" in content:
        print(f"Project '{project_name}' already exists in INFRA.md")
        return

    project_path = f"~/dev/projects/side/{project_name}"
    project_row = f"| {project_name} | {project_path} | {project_type} | ⏳ | {port} |"

    lines = content.split("\n")
    inserted = False

    for i, line in enumerate(lines):
        if "| 프로젝트 | 경로 | 타입 | Coolify 배포 | 포트 |" in line:
            if i + 1 < len(lines):
                lines.insert(i + 2, project_row)
                inserted = True
                break

    if not inserted:
        print("ERROR: Side 프로젝트 테이블을 찾을 수 없습니다")
        sys.exit(1)

    # DB 정보 추가
    if database_url:
        db_name = f"{project_name.replace('-', '_')}_db"
        db_row = f"| {db_name} | {project_name} 프로젝트 | {database_url} |"
        for i, line in enumerate(lines):
            if "### dev-server PostgreSQL" in line:
                for j in range(i, min(i + 10, len(lines))):
                    if "| DB | 용도 | 접속 |" in lines[j]:
                        lines.insert(j + 2, db_row)
                        break
                break

    INFRA_DOC_PATH.write_text("\n".join(lines), encoding="utf-8")

    # Git 커밋
    shared_docs_dir = str(INFRA_DOC_PATH.parent)
    subprocess.run(["git", "add", "INFRA.md"], cwd=shared_docs_dir, check=True)
    subprocess.run(
        ["git", "commit", "-m", f"docs: {project_name} 인프라 정보 추가"],
        cwd=shared_docs_dir,
        check=True,
    )
    subprocess.run(["git", "push"], cwd=shared_docs_dir, check=False)
    print(f"INFRA.md updated with {project_name} (port: {port})")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: update-infra.py <project-name> <project-type> <port> [--db <database_url>]")
        sys.exit(1)

    name = sys.argv[1]
    ptype = sys.argv[2]
    port = sys.argv[3]
    db_url = None

    if "--db" in sys.argv:
        idx = sys.argv.index("--db")
        if idx + 1 < len(sys.argv):
            db_url = sys.argv[idx + 1]

    update_infra(name, ptype, port, db_url)
