---
name: coding-workflow
description: >-
  Side 프로젝트 개발 워크플로우 자동화. 프로젝트 셋업부터 Linear 이슈 관리,
  Git 브랜치, DB 생성, 코딩, 테스트, PR 생성까지 Phase 1~10 전체를 실행한다.
  트리거: 프로젝트 만들어, 앱 만들어, API 만들어, 기능 구현해, 개발해,
  KOMCA-/HON-/LAZ- 이슈 처리, 코딩/개발 키워드 감지 시 사용.
---

# Coding Workflow

Side 프로젝트 개발 Phase 1~10 자동화. Claude Code가 직접 모든 단계를 수행한다.

## Workflow

### Phase 1: Linear 이슈 업데이트

이슈 번호가 있으면 Linear MCP로 상태 변경:

```
linear MCP: update_issue → state: "In Progress"
linear MCP: create_comment → "개발 시작: {task_description}"
```

이슈 번호 없으면 건너뛴다.

### Phase 2: 프로젝트 디렉토리 생성

```bash
mkdir -p ~/dev/projects/side/{project-name}
```

- 프로젝트명: kebab-case (예: `todo-app`, `auth-service`)
- `~/dev/projects/side/CLAUDE.md` 복사 (존재하면)
- 템플릿 필요 시 `~/dev/projects/side/template/` 참조 (CLAUDE.md의 템플릿 표 확인)

### Phase 3: Git 초기화 + 브랜치

```bash
git init
git checkout -b feature/{ISSUE-123}-{project-name}
# 이슈 없으면: feature/{project-name}
```

### Phase 4: DB 생성 (선택)

백엔드 프로젝트이거나 사용자가 DB를 요청한 경우:

```bash
# dev-server PostgreSQL 컨테이너에서 생성
ssh dev-server "docker exec -i {container_id} psql -U postgres -c 'CREATE DATABASE {project_name}_db;'"
```

- DB명: `{project_name}_db` (하이픈 → 언더스코어)
- DATABASE_URL: `postgresql://{user}:{pass}@192.168.0.67:5432/{db_name}`
- `.env`에 DATABASE_URL 추가

### Phase 5: INFRA.md 업데이트 + 포트 할당

포트 자동 할당:
```bash
python3 {SKILL_DIR}/scripts/auto-assign-port.py backend   # 10000-10999
python3 {SKILL_DIR}/scripts/auto-assign-port.py frontend  # 11000-11999
```

`~/projects/shared-docs/INFRA.md`에 프로젝트 정보 추가 후 커밋.

### Phase 6: 코딩

Claude Code가 직접 개발 수행:
- 프로젝트 구조 설계 및 파일 생성
- 코드 작성 (TypeScript strict, `any` 금지)
- `.env.example` 생성 (실제 `.env`는 커밋 금지)
- pnpm 사용, Tailwind CSS v4 + CSS 변수

개발 규칙은 `references/dev-rules.md` 참조.

### Phase 7: 테스트

```bash
pnpm install
pnpm test          # 유닛테스트
pnpm build         # 빌드 확인
pnpm lint          # 린트
pnpm type-check    # 타입 체크
```

빌드 실패 시 수정 후 재시도 (최대 3회).

### Phase 8: Linear 이슈 "In Review"

```
linear MCP: update_issue → state: "In Review"
linear MCP: create_comment → "개발 완료. 테스트 통과. PR 생성 예정."
```

### Phase 9: PR 생성

```bash
git add .
git commit -m "feat({ISSUE-123}): {task_description}"
git push -u origin feature/{ISSUE-123}-{project-name}
gh pr create --title "feat({ISSUE-123}): {description}" --base develop
```

### Phase 10: 완료 보고

사용자에게 최종 보고:
- 프로젝트명, Linear 이슈, PR URL
- 테스트 결과 (유닛/빌드/린트/타입체크)
- 다음 단계 (Coolify 배포 등)

## 자동 추출 규칙

요청에서 다음을 자동 추출:

| 항목 | 규칙 |
|------|------|
| 프로젝트명 | 핵심 키워드 → kebab-case |
| 이슈번호 | `KOMCA-`, `HON-`, `LAZ-` 패턴 |
| 포트 | `auto-assign-port.py`로 자동 할당 |
| DB | "DB", "데이터베이스", "PostgreSQL" 키워드 또는 백엔드 프로젝트 |
| 타입 | "React", "Vue" → frontend, 기본 → backend |

## 프로젝트 경로 규칙

- **경로**: `~/dev/projects/side/{project-name}`
- **네이밍**: kebab-case
- 현재 디렉토리(pwd), 홈 디렉토리 직접 사용 금지

## 스크립트

- `scripts/auto-assign-port.py` - INFRA.md 기반 포트 자동 할당
- `scripts/update-infra.py` - INFRA.md에 프로젝트 정보 추가

## 참조

- `references/dev-rules.md` - 개발 규칙 및 컨벤션
- `~/projects/shared-docs/INFRA.md` - 인프라 정보 (포트, DB, 서버)
