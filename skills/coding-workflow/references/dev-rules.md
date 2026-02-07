# 개발 규칙

## 코드 스타일

- TypeScript strict, `any` 금지
- 경로 별칭 `@/*` 사용
- Tailwind CSS v4 + CSS 변수, 하드코딩 색상/inline style 금지
- 함수형 컴포넌트만
- pnpm 패키지 매니저

## API 응답 포맷

```typescript
{ success: true, data: { ... } }
{ success: false, error: { message: "에러", code: "ERROR_CODE" } }
```

## 환경 변수

- `.env` 커밋 금지, `.env.example`만 포함
- API 키/비밀번호 하드코딩 금지

## Git 규칙

- 브랜치: `main`(운영), `develop`(개발), `feature/ISSUE-번호-설명`
- 커밋: `feat(ISSUE-123): 설명`, `fix(ISSUE-456): 설명`
- main 직접 푸시 금지, PR 필수

## 포트 할당

| 범위 | 용도 |
|------|------|
| 10000-10999 | API (백엔드) |
| 11000-11999 | Web (프론트엔드) |
| 12000-12999 | 인프라 |

## 테마 변수

```css
--bg-primary, --bg-secondary, --bg-tertiary
--text-primary, --text-secondary, --text-muted
--accent-primary, --success, --warning, --error, --info
--honey-primary (LazyBee 브랜딩: rgb(255 200 50))
```

## 에러 처리

- 빌드 실패: 3회 재시도
- 테스트 실패: 로그 확인 → 원인 파악 → 수정
- 3회 실패 시 사용자에게 보고

## Linear 이슈 연동

이슈 번호 패턴: `KOMCA-`, `HON-`, `LAZ-`

| 시점 | 상태 |
|------|------|
| 작업 시작 | In Progress |
| 개발 완료 | In Review |
| PR 머지 | Done |
