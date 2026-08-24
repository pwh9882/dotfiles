---
name: weekly-report
description: Linear 이슈와 댓글에서 지난 한 주의 작업을 수집해 Obsidian human-inbox/weekly-notes/에 주간 리포트 초안을 작성한다. 사용자가 "주간 리포트", "위클리 리포트", "weekly report" 초안 작성을 요청하면 사용한다.
---

# Weekly Report 초안 작성

매주 월요일 기준으로 지난 한 주의 작업을 Linear에서 수집해 리포트 초안을 만든다.

- 저장 위치: `~/Documents/Obsidian Vault/human-inbox/weekly-notes/`
- 파일명(= Obsidian 노트 제목): `YYYY-MM-DD (월) Weekly Report.md` — 예: `2026-07-06 (월) Weekly Report.md`
- 날짜는 오늘이 월요일이면 오늘, 아니면 다가오는 월요일 (`date -v+mon +%F`). 월요일 기준이므로 요일 표기는 항상 `(월)`.
- 기간: 직전 월요일부터 그 일요일까지. 이전 리포트의 기간과 이어져야 한다.

## Step 1: 이전 리포트 읽기

`weekly-notes/`에서 파일명 정렬상 가장 최근 파일을 읽는다.

- 진행 중인 프로젝트 목록 확인 (TITANS, AIOps, RAG, 헬스케어센터 등)
- 저번주 "예정사항"에서 이번주 "진행사항"으로 이어지는 항목 파악
- 포맷과 구조 참고

이전 파일이 없으면(첫 실행) 사용자에게 알리고 이 스킬의 구조 템플릿만으로 진행한다.

## Step 2: Linear 이슈 수집

Linear MCP `list_issues`로 지난 1주간 업데이트된 내 이슈를 가져온다
(assignee: me, updatedAt: -P7D, orderBy: updatedAt, limit: 50).

- 프로젝트별로 묶어야 하므로 project 필드를 확인한다.
- status 변화를 챙긴다: Done으로 전환된 것, 새로 In Progress가 된 것.
- 이번주 새로 생성된 이슈도 따로 본다.

## Step 3: 이슈 본문과 댓글 읽기

각 이슈에 대해 `get_issue`로 본문을, `list_comments`로 댓글을 모두 읽는다. 배포 결과나 측정 수치 같은 핵심 정보가 댓글에만 있는 경우가 많다.

수집할 것: 무엇을 했는지(변경·수정·배포·실험) / 발견한 문제와 해결 여부 / 측정 수치(있으면 표로) / 현재 상태(완료·진행중·블로킹).

## Step 4: 프로젝트별 그룹핑

이전 리포트의 프로젝트 순서를 따르고, 이번주 활동이 없는 프로젝트는 뺀다. 새로 시작한 프로젝트는 추가한다.

## Step 5: 초안 작성

구조:

```
**기간**: 2026-MM-DD ~ 2026-MM-DD / **Author**: 박우혁

# 진행사항

## 프로젝트명
- Linear 이슈 링크
    - 1~3줄 요약
    - 수치가 있으면 테이블

# 예정사항

## 프로젝트명
- 다음주 할 일 bullet
```

톤:

- 간결한 구어체: "~했습니다", "~중입니다", "~하겠습니다"
- Linear 이슈 링크를 항목 앞에 두고, indent로 그 이슈에서 한 일을 설명
- 세부 기술 내용은 Linear 링크에 맡기고 리포트에는 1~3줄 요약만
- 판단은 직접 밝힌다: "~로 보입니다", "~해서 계속 진행하겠습니다"
- 미정 사항은 물음표 허용: "미팅 참여?"

쓰지 않는 것:

- 하단 `---` 아래 진행노트 영역 (미팅 중/후에 사용자가 직접 적는다)
- 증상→원인→해결 풀스토리 (Linear 이슈에 이미 있다)

## Step 6: 저장과 확인

초안을 `weekly-notes/YYYY-MM-DD (월) Weekly Report.md`로 저장하고 사용자에게 검토를 요청한다.

체크리스트:

- [ ] 이전 리포트의 예정사항 중 이번주에 진행된 것이 빠지지 않았는가
- [ ] Linear 이슈 링크가 정확한가
- [ ] 프로젝트 누락이 없는가
- [ ] 수치나 결과가 있는 항목이 들어갔는가

## 도구 규칙

- Linear read (`list_issues`, `get_issue`, `list_comments`): 자율 사용.
- Linear write (`save_comment` 등): 사용자 명시적 허락 후에만.
- 파일 쓰기는 `weekly-notes/` 안에서만 한다. human-inbox의 다른 위치는 건드리지 않는다.
