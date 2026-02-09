---
description: "Git 원자적 커밋 분할 스킬. 변경 파일을 논리적 단위로 분석하여 원자적 커밋으로 분할합니다. 파일 수, 디렉토리, 컴포넌트 유형별 분할 규칙을 적용합니다."
triggers:
  - "원자적 커밋"
  - "커밋 분할"
  - "atomic commit"
  - "커밋 정리"
  - "커밋 나누기"
  - "분리 커밋"
  - "커밋 쪼개기"
  - "git 정리"
---

# Git 원자적 커밋 분할

## 개요

변경된 파일들을 논리적으로 관련된 단위로 분할하여 각각 독립적인 커밋으로 만듭니다.
각 커밋은 독립적으로 revert 가능하고, 코드 리뷰가 용이하며, git bisect에 유용합니다.

## 실행 절차

### Step 1: 변경 사항 분석

```bash
# 변경된 파일 목록 확인
git diff --name-only
git diff --cached --name-only
git status --porcelain

# 변경 통계
git diff --stat
```

### Step 2: 최소 커밋 수 결정

| 변경 파일 수 | 최소 커밋 수 |
|-------------|-------------|
| 1~2 | 1 |
| 3~4 | 2 |
| 5~9 | 3 |
| 10+ | ceil(파일수 / 3) |

**공식**: `min_commits = max(1, ceil(file_count / 3))`

### Step 3: 분할 기준 적용

아래 기준 중 하나라도 해당되면 별도 커밋으로 분리:

1. **디렉토리/모듈이 다른 경우**
   - `src/api/` vs `src/components/` → 분리
   - `backend/` vs `frontend/` → 분리

2. **컴포넌트 유형이 다른 경우**
   - UI 컴포넌트 vs 비즈니스 로직 → 분리
   - 설정 파일 vs 소스 코드 → 분리
   - 테스트 vs 구현 → 분리

3. **독립적으로 revert 가능한 경우**
   - 리팩토링 vs 기능 추가 → 분리
   - 버그 수정 vs 기능 개선 → 분리

4. **의존성이 없는 경우**
   - 서로 참조하지 않는 변경 → 분리

### Step 4: 커밋 순서 (의존성 레벨)

의존 관계에 따라 낮은 레벨부터 커밋:

```
Level 0: 유틸리티, 상수, 타입 정의
Level 1: 모델, 스키마, 인터페이스
Level 2: 서비스, 비즈니스 로직
Level 3: API 엔드포인트, 컨트롤러, UI 컴포넌트
Level 4: 설정, 인프라, CI/CD
```

### Step 5: 커밋 스타일 감지

최근 30개 커밋에서 스타일 자동 감지:

```bash
git log --oneline -30
```

**스타일 분류**:

| 스타일 | 패턴 | 예시 |
|--------|------|------|
| SEMANTIC | `type(scope): msg` | `feat(auth): add JWT login` |
| PLAIN | 동사로 시작 | `Add user authentication` |
| SHORT | 간결한 설명 | `fix login bug` |

감지된 스타일에 맞춰 커밋 메시지 작성.

### Step 6: 커밋 실행

```bash
# 각 논리 단위별로 파일 스테이징 후 커밋
git add <파일1> <파일2>
git commit -m "$(cat <<'EOF'
feat(auth): add JWT token validation

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

git add <파일3> <파일4>
git commit -m "$(cat <<'EOF'
test(auth): add JWT validation tests

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

## 분할 예시

### 예시: 사용자 인증 기능 추가 (8파일)

```
변경 파일:
  src/types/auth.ts
  src/lib/jwt.ts
  src/services/auth-service.ts
  src/api/auth/route.ts
  src/components/LoginForm.tsx
  src/hooks/useAuth.ts
  tests/auth-service.test.ts
  prisma/schema.prisma

분할 결과 (4 커밋):
  1. feat(db): add User model to Prisma schema
     → prisma/schema.prisma

  2. feat(auth): add JWT utilities and auth types
     → src/types/auth.ts, src/lib/jwt.ts

  3. feat(auth): implement auth service and API route
     → src/services/auth-service.ts, src/api/auth/route.ts

  4. feat(auth): add login UI and auth hook with tests
     → src/components/LoginForm.tsx, src/hooks/useAuth.ts, tests/auth-service.test.ts
```

## 주의사항

- 각 커밋은 **빌드가 깨지지 않아야** 합니다
- 타입 정의는 해당 타입을 사용하는 코드보다 **먼저** 커밋
- 마이그레이션 파일은 스키마 변경과 **같은** 커밋에 포함
- `.gitignore`, `package.json` 등 설정 변경은 별도 커밋 권장
- 1개 파일만 변경된 경우 분할하지 않음
