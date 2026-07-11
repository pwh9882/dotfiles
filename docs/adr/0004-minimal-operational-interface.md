# ADR-0004: Minimal Operational Interface

## 상태

Accepted, 2026-07-11.

## 맥락

Machine Profile에는 다섯 Role이 있었지만 모두 `bin`, `agents-links`를 같은 순서로 선택했습니다. Feature Registry는 정적인 온보딩 정보를 parser와 전용 Doctor로 제공했고, Workspace Registry에는 `dotfiles` 한 항목만 있었습니다. 이 세 Module은 CLI 명령, Registry, 검증 규칙, 전용 테스트를 사용자에게 노출했습니다.

확인해보니 Profile·Feature·Workspace Interface를 제거해도 설치와 WezTerm 기능의 복잡도가 다른 호출자로 이동하지 않았습니다. 고정 Module 순서, 문서, 일반 Git 상태 확인으로 필요한 동작이 남았습니다.

## 결정

- 기본 `plan`과 `apply`는 `bin agents-links`를 고정 순서로 선택합니다.
- Instance와 Role은 에이전트·인프라 identity에 사용하며 dotfiles Module 선택에는 사용하지 않습니다.
- Feature Registry와 `dotfiles tour`를 제거하고 한 페이지짜리 사용 안내를 원본으로 둡니다.
- 단일 Workspace Registry와 `dotfiles context`를 제거합니다. 필요 정보는 `llm-instance`, `pwd`, Git 명령으로 확인합니다.
- shell 시작 시 자동 `pull`을 실행하지 않습니다. background `fetch`와 업데이트 알림만 수행합니다.
- 두 번째 실제 Adapter나 Role별 Module 차이가 생기면 해당 Seam을 새 결정으로 검토합니다.

## 검토한 대안

### Role과 Capability Registry를 추가 분리

현재 Role별 Module 차이가 없어 Registry 수와 교차 검증만 늘어납니다.

### `dotfiles update` 추가

일반 `git pull --ff-only`가 필요한 동작을 이미 제공합니다. 별도 명령은 checkout rollback과 package 적용까지 하나의 계약이 필요해질 때 검토합니다.

### Feature Registry 유지

기능 목록의 변경 빈도가 낮고 실행 Adapter가 없습니다. Markdown 사용 안내가 같은 정보를 더 직접적으로 전달합니다.

## 결과

- 일상 Interface는 `doctor`, `plan`, `apply`, `history`, `rollback`으로 줄었습니다.
- Module 선택은 identity 파일과 Registry 가용성에 의존하지 않습니다.
- 온보딩 내용은 [`docs/runbooks/daily-dotfiles.md`](../runbooks/daily-dotfiles.md)에서 바로 읽습니다.
- `CONTEXT.md`는 현재 구현된 Instance, Module, Local Adapter, Transaction, Writer Lock만 공통 용어로 유지합니다.
