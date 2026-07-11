# ADR-0001: Single-Context Domain Model

## 상태

Accepted, 2026-07-10. 도메인 범위는 [ADR-0004](0004-minimal-operational-interface.md)에서 축소했습니다.

## 맥락

Installer, Machine Profile, Execution Context, Workspace는 하나의 적용·검증 흐름에서 서로의 식별자를 사용합니다. 현재 저장소와 운영자는 각각 하나이며, 영역별 context를 먼저 나누면 공통 용어와 invariant를 여러 위치에서 관리하게 됩니다.

모든 구현 세부사항을 루트 context에 넣으면 agent가 작업과 무관한 내용을 반복해서 읽습니다. 공통 언어와 세부 구현 문서를 분리할 위치가 필요합니다.

## 결정

- 루트 `CONTEXT.md` 하나를 공통 도메인 언어와 시스템 관계의 원본으로 사용합니다.
- Module별 상세 설계는 `docs/architecture/`에 둡니다.
- 장기 설계 결정은 `docs/adr/`에 둡니다.
- 적용·검증·복구 절차는 `docs/runbooks/`에 둡니다.
- `AGENTS.md`와 `CLAUDE.md`는 작업 규칙과 문서 탐색 경로를 제공합니다.

LLM-WIKI의 durable 결정은 `decisions/2026-07-10-dotfiles-single-context-domain-model.md`에 기록했습니다.

## 검토한 대안

### 처음부터 multi-context 사용

`CONTEXT-MAP.md` 라우팅과 중복 용어 관리가 즉시 필요합니다. 현재 Module은 독립된 생명주기보다 교차 의존이 많아 분리 이점이 작습니다.

### README와 agent 지침만 사용

사용법과 작업 규칙은 남지만 Workspace, Target, Execution Context의 관계와 invariant를 정의할 원본이 없습니다.

### 모든 내용을 루트 CONTEXT.md에 기록

루트 문서가 구현 로그와 예제로 커집니다. 공통 언어만 루트에 유지하고 세부사항을 목적별 문서로 내립니다.

## 결과

- 사람과 agent가 같은 용어로 시스템을 설명합니다.
- 공통 invariant 변경은 한 문서에서 확인합니다.
- 특정 Module을 변경할 때 상세 architecture 문서를 추가로 읽습니다.
- 별도 저장소·release lifecycle·소유권 또는 용어 충돌이 생기면 multi-context 전환을 새 ADR로 기록합니다.
