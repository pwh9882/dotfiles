# Domain Docs

이 저장소는 single-context 구조를 사용합니다.

## 탐색 순서

1. 루트 [`CONTEXT.md`](../../CONTEXT.md)에서 공통 용어, Module 관계, invariant를 읽습니다.
2. 작업 영역과 관련된 [`docs/adr/`](../adr/) 결정을 읽습니다.
3. 구현 구조는 [`docs/architecture/`](../architecture/)에서 확인합니다.
4. 적용·검증·복구 절차는 [`docs/runbooks/`](../runbooks/)에서 확인합니다.

파일이 아직 없으면 별도 오류로 다루지 않고 현재 자료로 계속 탐색합니다.

## 소비 규칙

- 이슈 제목, 가설, 테스트, 구현 제안에서 `CONTEXT.md`의 용어를 사용합니다.
- 같은 개념에 새 이름을 만들기 전에 glossary를 확인합니다.
- 필요한 개념이 glossary에 없으면 실제 domain gap인지 확인하고 `CONTEXT.md` 갱신을 제안합니다.
- 기존 ADR과 충돌하는 제안은 ADR 번호와 충돌 이유를 함께 밝힙니다.
- 구현 로그와 머신별 일시 상태를 `CONTEXT.md`에 넣지 않습니다.

## 구조 변경

multi-context 전환 조건은 [ADR-0001](../adr/0001-single-context-domain-model.md)에 정의되어 있습니다. 조건이 발생하기 전에는 `CONTEXT-MAP.md`나 영역별 `CONTEXT.md`를 만들지 않습니다.
