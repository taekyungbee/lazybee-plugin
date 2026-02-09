---
description: "AST-Grep 구조적 코드 검색/변환 도구. ast-grep(sg) CLI를 활용하여 AST 기반 정확한 패턴 매칭, 코드 검색, 리팩토링을 수행합니다."
triggers:
  - "AST 검색"
  - "구조적 검색"
  - "패턴 검색"
  - "ast-grep"
  - "sg 검색"
  - "코드 패턴"
  - "구조적 변환"
  - "AST 리팩토링"
---

# AST-Grep 구조적 코드 검색/변환

## 개요

`ast-grep`(CLI: `sg`)은 AST(Abstract Syntax Tree) 기반 구조적 코드 검색/변환 도구입니다.
텍스트 기반 grep과 달리 코드의 구조를 이해하여 정확한 패턴 매칭을 수행합니다.

## 설치 확인

```bash
# 설치 확인
sg --version

# 미설치 시
brew install ast-grep    # macOS
npm install -g @ast-grep/cli  # npm
```

## 핵심 CLI 사용법

### 검색 (Search)

```bash
# 기본 패턴 검색
sg --pattern '$PATTERN' [--lang LANG] [PATH]

# 예시: console.log 찾기
sg --pattern 'console.log($$$ARGS)' --lang typescript

# JSON 출력
sg --pattern '$PATTERN' --json
```

### 변환 (Rewrite)

```bash
# 패턴 변환
sg --pattern '$OLD' --rewrite '$NEW' [--lang LANG] [PATH]

# 예시: var를 const로 변환
sg --pattern 'var $NAME = $VALUE' --rewrite 'const $NAME = $VALUE' --lang typescript
```

## 메타변수 (Metavariables)

| 메타변수 | 의미 | 예시 |
|----------|------|------|
| `$VAR` | 단일 AST 노드 매칭 | `$FN($ARG)` |
| `$$$VARS` | 0개 이상 복수 노드 매칭 | `console.log($$$ARGS)` |
| `$_` | 와일드카드 (이름 무관) | `if ($_ ) { $$$BODY }` |

## 지원 언어 (25개)

TypeScript, JavaScript, Python, Java, Kotlin, Go, Rust, C, C++, C#, Swift, Ruby, PHP, Lua, Dart, Elixir, Scala, Bash, HTML, CSS, JSON, YAML, TOML, SQL, GraphQL

## 자주 쓰는 패턴 예시

### TypeScript / JavaScript

```bash
# console.log 전체 찾기
sg --pattern 'console.log($$$ARGS)' --lang typescript

# any 타입 사용 찾기
sg --pattern '$VAR: any' --lang typescript

# React useState 찾기
sg --pattern 'const [$STATE, $SETTER] = useState($$$INIT)' --lang tsx

# async 함수 찾기
sg --pattern 'async function $NAME($$$PARAMS) { $$$BODY }' --lang typescript

# import 문 찾기
sg --pattern 'import $$$IMPORTS from $SOURCE' --lang typescript

# @ts-ignore를 @ts-expect-error로 변환
sg --pattern '// @ts-ignore' --rewrite '// @ts-expect-error' --lang typescript

# var를 const로 변환
sg --pattern 'var $NAME = $VALUE' --rewrite 'const $NAME = $VALUE' --lang typescript

# == 를 === 로 변환
sg --pattern '$A == $B' --rewrite '$A === $B' --lang typescript

# Promise.then을 async/await로 (단순 케이스)
sg --pattern '$PROMISE.then($CALLBACK)' --lang typescript
```

### Python

```bash
# print 문 찾기 (Python은 colon 없이 검색)
sg --pattern 'print($$$ARGS)' --lang python

# for 루프 찾기
sg --pattern 'for $VAR in $ITER:' --lang python

# 데코레이터 찾기
sg --pattern '@$DECORATOR' --lang python
```

### Java

```bash
# System.out.println 찾기
sg --pattern 'System.out.println($$$ARGS)' --lang java

# try-catch 찾기
sg --pattern 'try { $$$BODY } catch ($EX) { $$$HANDLER }' --lang java
```

## 빈 결과 시 힌트

검색 결과가 없을 때 확인할 사항:

1. **언어 지정 확인**: `--lang` 플래그가 올바른지 (tsx vs typescript)
2. **Python colon**: Python에서 `if $COND:` 처럼 colon 포함 필요
3. **세미콜론**: JS/TS에서 세미콜론은 보통 생략 가능
4. **타입 어노테이션**: `function $FN($P: $T)` 처럼 타입도 패턴에 포함
5. **JSX**: React JSX 검색 시 `--lang tsx` 사용
6. **경로**: 기본값은 현재 디렉토리, 필요 시 경로 지정

## 고급: 규칙 파일 (YAML)

복잡한 패턴은 YAML 규칙 파일로 정의:

```yaml
# sg-rules/no-console.yml
id: no-console-log
language: typescript
rule:
  pattern: console.log($$$ARGS)
message: "console.log 사용 금지. logger를 사용하세요."
severity: warning
fix: "logger.debug($$$ARGS)"
```

```bash
# 규칙 파일로 검색
sg scan --rule sg-rules/no-console.yml

# 규칙 파일로 자동 수정
sg scan --rule sg-rules/no-console.yml --update-all
```

## Bash에서 실행 시 주의

- `$` 메타변수는 반드시 **싱글쿼트**로 감싸기: `sg --pattern '$VAR'`
- 더블쿼트 사용 시 셸이 `$VAR`를 환경변수로 해석
- 출력이 많을 경우 `--json | jq` 파이프로 필터링
