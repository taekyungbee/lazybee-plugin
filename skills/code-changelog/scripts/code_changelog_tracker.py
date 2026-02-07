#!/usr/bin/env python3
"""Code Changelog Tracker - AI 코드 변경사항 자동 문서화"""

import os
import json
import datetime
import re
from pathlib import Path


class CodeChangeLogger:
    def __init__(self, project_name: str, user_request: str = "", reviews_dir: str = "reviews"):
        self.project_name = project_name
        self.user_request = user_request
        self.reviews_dir = Path(reviews_dir)
        self.changes: list[dict] = []
        self.timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    def log_file_creation(self, file_path: str, content: str, reason: str) -> None:
        self.changes.append({
            "type": "create",
            "file_path": file_path,
            "content": content,
            "reason": reason,
        })

    def log_file_modification(self, file_path: str, old_content: str, new_content: str, reason: str) -> None:
        self.changes.append({
            "type": "modify",
            "file_path": file_path,
            "old_content": old_content,
            "new_content": new_content,
            "reason": reason,
        })

    def log_file_deletion(self, file_path: str, content: str, reason: str) -> None:
        self.changes.append({
            "type": "delete",
            "file_path": file_path,
            "content": content,
            "reason": reason,
        })

    def log_bug_fix(self, file_path: str, old_content: str, new_content: str, bug_desc: str, fix_desc: str) -> None:
        self.changes.append({
            "type": "bugfix",
            "file_path": file_path,
            "old_content": old_content,
            "new_content": new_content,
            "bug_description": bug_desc,
            "fix_description": fix_desc,
        })

    def log_refactoring(self, file_path: str, old_content: str, new_content: str, refactor_type: str, reason: str) -> None:
        self.changes.append({
            "type": "refactoring",
            "file_path": file_path,
            "old_content": old_content,
            "new_content": new_content,
            "refactor_type": refactor_type,
            "reason": reason,
        })

    def _generate_markdown(self) -> str:
        now = datetime.datetime.now()
        lines = [
            f"# {self.project_name}",
            f"\n> {now.strftime('%Y-%m-%d %H:%M:%S')}",
        ]
        if self.user_request:
            lines.append(f"\n## 요청사항\n{self.user_request}")

        lines.append("\n## 변경사항\n")
        for i, change in enumerate(self.changes, 1):
            ctype = change["type"]
            fpath = change.get("file_path", "")
            reason = change.get("reason", change.get("fix_description", ""))

            icon = {"create": "+", "modify": "~", "delete": "-", "bugfix": "!", "refactoring": "^"}.get(ctype, "?")
            lines.append(f"### {i}. [{icon}] `{fpath}`")
            lines.append(f"**사유**: {reason}\n")

            if ctype == "create":
                lines.append(f"```\n{change['content'][:500]}\n```\n")
            elif ctype in ("modify", "bugfix", "refactoring"):
                old = change.get("old_content", "")[:300]
                new = change.get("new_content", "")[:300]
                lines.append(f"**Before:**\n```\n{old}\n```\n")
                lines.append(f"**After:**\n```\n{new}\n```\n")

        return "\n".join(lines)

    def save_review(self) -> Path:
        self.reviews_dir.mkdir(parents=True, exist_ok=True)
        md = self._generate_markdown()
        filepath = self.reviews_dir / f"{self.timestamp}.md"
        filepath.write_text(md, encoding="utf-8")
        return filepath

    def _update_summary(self) -> None:
        md_files = sorted(self.reviews_dir.glob("*.md"))
        md_files = [f for f in md_files if f.name not in ("README.md", "SUMMARY.md")]
        lines = ["# Summary\n", "* [Home](README.md)\n"]
        for f in md_files:
            lines.append(f"* [{f.stem}]({f.name})")
        (self.reviews_dir / "SUMMARY.md").write_text("\n".join(lines), encoding="utf-8")

    def update_index_html(self) -> None:
        md_files = sorted(self.reviews_dir.glob("*.md"), reverse=True)
        md_files = [f for f in md_files if f.name not in ("README.md", "SUMMARY.md")]
        if not md_files:
            return

        file_links = "\n".join(
            f'            <a href="#" onclick="loadDoc(\'{f.name}\')" class="nav-link">{f.stem}</a>'
            for f in md_files
        )
        default_file = md_files[0].name

        html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Code Changelog</title>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #0d1117; color: #c9d1d9; display: flex; height: 100vh; }}
  .sidebar {{ width: 260px; background: #161b22; border-right: 1px solid #30363d; overflow-y: auto; padding: 16px; }}
  .sidebar h2 {{ color: #58a6ff; margin-bottom: 12px; font-size: 14px; }}
  .nav-link {{ display: block; padding: 8px 12px; color: #8b949e; text-decoration: none; border-radius: 6px; font-size: 13px; margin-bottom: 2px; }}
  .nav-link:hover, .nav-link.active {{ background: #21262d; color: #c9d1d9; }}
  .content {{ flex: 1; overflow-y: auto; padding: 32px; }}
  .content h1 {{ color: #58a6ff; }} .content h2 {{ color: #79c0ff; }} .content h3 {{ color: #d2a8ff; }}
  .content code {{ background: #161b22; padding: 2px 6px; border-radius: 4px; }}
  .content pre {{ background: #161b22; padding: 16px; border-radius: 8px; overflow-x: auto; border: 1px solid #30363d; }}
</style>
</head>
<body>
<div class="sidebar">
  <h2>Changelog</h2>
  <nav>
{file_links}
  </nav>
</div>
<div class="content" id="content">Loading...</div>
<script>
async function loadDoc(name) {{
  const res = await fetch(name);
  const md = await res.text();
  document.getElementById('content').innerHTML = marked.parse(md);
  document.querySelectorAll('.nav-link').forEach(a => a.classList.remove('active'));
  document.querySelector(`[onclick*="${{name}}"]`)?.classList.add('active');
}}
loadDoc('{default_file}');
</script>
</body>
</html>"""
        (self.reviews_dir / "index.html").write_text(html, encoding="utf-8")

    def _ensure_readme(self) -> None:
        readme = self.reviews_dir / "README.md"
        if not readme.exists():
            readme.write_text(f"# {self.project_name} - Code Changelog\n\nAI가 생성한 코드 변경사항 문서입니다.\n", encoding="utf-8")

    def save_and_build(self) -> Path:
        self._ensure_readme()
        filepath = self.save_review()
        self._update_summary()
        self.update_index_html()
        return filepath


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "init":
            logger = CodeChangeLogger("My Project")
            logger._ensure_readme()
            logger._update_summary()
            logger.update_index_html()
            print("Initialized reviews/ directory")
        elif cmd == "serve":
            port = int(sys.argv[2]) if len(sys.argv) > 2 else 4000
            import http.server
            import socketserver
            os.chdir("reviews")
            with socketserver.TCPServer(("", port), http.server.SimpleHTTPRequestHandler) as httpd:
                print(f"Serving at http://localhost:{port}")
                httpd.serve_forever()
    else:
        print("Usage: python code_changelog_tracker.py [init|serve [port]]")
