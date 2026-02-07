---
name: gemini-cli
description: >-
  Gemini CLI를 활용한 이미지 생성/분석, 프론트엔드 UI 리뷰, 텍스트 처리 스킬.
  트리거: "gemini로", "이미지 만들어", "UI 리뷰해", "스크린샷 분석",
  "Gemini한테 물어봐", "이미지 생성", "화면 피드백" 등 Gemini 활용 요청 시 사용.
---

# Gemini CLI Integration

Gemini CLI(`gemini`)를 통해 이미지 생성/분석, UI 리뷰, 텍스트 처리를 수행한다.

## 모델 선택 기준

| 모델 | 용도 | 비용 |
|------|------|------|
| `gemini-2.5-flash` | 기본 텍스트, 간단한 분석 | 무료 티어 |
| `gemini-2.5-flash-lite` | 단순 분류, 요약 | 최저비용 |
| `gemini-2.5-pro` | 복잡한 분석, 코드 리뷰 | 유료 |
| `gemini-2.5-flash-image` | 이미지 생성/편집 | 유료 |

기본값: `gemini-2.5-flash` (비용 효율)

## 사용 패턴

### 1. 이미지 생성

```bash
gemini -m gemini-2.5-flash-image -p "Generate an image: [설명]. Save to [경로]"
```

아이콘, 로고, 배경, 목업 등 프로젝트에 필요한 이미지 생성.

### 2. 이미지/스크린샷 분석

```bash
gemini -m gemini-2.5-flash -p "Analyze this image: [이미지경로]. [분석 요청]"
```

- UI 스크린샷 → 개선점 피드백
- 에러 스크린샷 → 문제 분석
- 디자인 시안 → 구현 가이드 추출

### 3. 프론트엔드 UI 리뷰

```bash
gemini -m gemini-2.5-flash -p "Review this UI screenshot: [경로]. Check: layout, color contrast, spacing, accessibility, mobile responsiveness. Respond in Korean."
```

### 4. 텍스트 처리

```bash
gemini -m gemini-2.5-flash -p "[프롬프트]"
```

번역, 요약, 분류 등 단순 텍스트 작업.

## 주의사항

- `-p` 플래그로 non-interactive 모드 사용 (파이프라인 호환)
- 출력에 deprecation warning 포함됨 → `2>/dev/null`로 억제 가능
- 이미지 생성 시 저장 경로를 명시적으로 지정
- 긴 프롬프트는 heredoc 사용:
  ```bash
  gemini -m gemini-2.5-flash -p "$(cat <<'EOF'
  여기에 긴 프롬프트
  EOF
  )"
  ```
