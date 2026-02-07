---
name: codex-review
description: >-
  OpenAI Codex CLI를 활용한 코드 리뷰 및 설계 검증 스킬.
  트리거: "codex로 리뷰해", "코드 리뷰해줘", "PR 리뷰", "커밋 리뷰",
  "변경사항 검토", "코드 검토", "설계 검토", "아키텍처 리뷰",
  "codex로 설계 확인", "second opinion" 등 코드 리뷰/설계 검증 요청 시 사용.
---

# Codex CLI Code Review & Design Validation

Codex CLI를 통해 코드 리뷰(`codex review`) 및 설계 검증(`codex exec`)을 수행한다.

## 사용 패턴

### 1. 작업 중 변경사항 리뷰 (uncommitted)

```bash
codex review --uncommitted
```

staged, unstaged, untracked 파일 모두 포함하여 리뷰.

### 2. 브랜치 비교 리뷰

```bash
codex review --base main
codex review --base develop
```

현재 브랜치와 base 브랜치 간 diff 리뷰.

### 3. 특정 커밋 리뷰

```bash
codex review --commit <SHA>
```

### 4. 커스텀 리뷰 지시

```bash
codex review "보안 취약점 위주로 검토해줘"
codex review --uncommitted "성능 이슈 위주로 봐줘"
codex review --base main "OWASP Top 10 기준으로 검토"
```

### 5. PR 리뷰 워크플로우

```bash
# PR 브랜치에서 main 대비 리뷰
codex review --base main --title "feat(auth): OAuth2 구현"
```

## 모델 선택

```bash
# 기본 모델 사용
codex review --uncommitted

# 특정 모델 지정
codex review -c model="o3" --uncommitted
codex review -c model="o4-mini" --base main
```

## 설계 검증 워크플로우 (Claude → Codex → Claude)

Claude가 설계/계획을 수립한 후, Codex에게 second opinion을 요청하여 교차 검증하는 패턴.

**흐름**: Claude 설계 → Codex 검토/보완 제시 → Claude 판단 후 수용/수정

### 6. 아키텍처 설계 검증

```bash
# Claude가 설계한 내용을 파일로 저장 후 Codex에게 검토 요청
codex exec "$(cat <<'EOF'
아래 설계안을 검토하고 개선점을 제안해줘:
- 놓친 엣지 케이스
- 더 나은 패턴/구조
- 성능/확장성 우려사항

[설계 내용 또는 파일 참조]
EOF
)"
```

### 7. API/스키마 설계 리뷰

```bash
codex exec "src/api/ 디렉토리의 REST API 설계를 분석하고 RESTful 원칙 준수 여부를 평가해줘"
codex exec "prisma/schema.prisma의 데이터 모델을 분석하고 정규화/인덱싱 개선점을 제안해줘"
```

### 8. 구현 전 설계 교차 검증

```bash
# 프로젝트 구조 분석
codex exec "이 프로젝트의 디렉토리 구조와 의존성을 분석하고 순환 참조, 레이어 위반이 있는지 확인해줘"

# 특정 기능 설계 검토
codex exec "src/services/auth.ts의 인증 플로우를 분석하고 보안 취약점이 있는지 확인해줘"
```

Codex 결과를 Claude가 판단하여 수용할 것만 반영한다.

## 주의사항

- Codex CLI에 OpenAI API 키 또는 로그인 필요 (`codex login`)
- `--uncommitted` 없이 실행하면 마지막 커밋 기준 리뷰
- `codex exec`는 non-interactive 모드로 실행 (파이프라인 호환)
- `codex review` 결과는 stdout으로 출력 (파이프 가능)
- sandbox 환경에서 실행되므로 파일 시스템 안전
- Codex 제안은 참고용, 최종 판단은 Claude(또는 사용자)가 수행
