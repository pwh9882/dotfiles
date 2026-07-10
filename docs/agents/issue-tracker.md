# Issue Tracker: GitHub

이 저장소의 이슈와 PRD는 [`pwh9882/dotfiles`](https://github.com/pwh9882/dotfiles)의 GitHub Issues에서 관리합니다. 저장소 clone 안에서는 `gh`가 Git remote를 통해 대상 저장소를 자동으로 찾습니다.

## 명령

- 생성: `gh issue create --title "..." --body "..."`
- 조회: `gh issue view <번호> --comments`
- 목록: `gh issue list --state open --json number,title,body,labels,comments`
- 댓글: `gh issue comment <번호> --body "..."`
- label 추가·제거: `gh issue edit <번호> --add-label "..."` / `--remove-label "..."`
- 종료: `gh issue close <번호> --comment "..."`

여러 줄 본문은 임시 파일이나 heredoc을 사용해 shell quoting 문제를 피합니다. 이슈 생성·수정·종료는 현재 사용자 요청이 해당 변경을 포함할 때만 실행합니다.

## Skill 용어 매핑

- “issue tracker에 publish”: GitHub issue를 생성합니다.
- “relevant ticket을 fetch”: `gh issue view <번호> --comments`로 본문, label, 댓글을 함께 읽습니다.
- “AFK-ready”: `docs/agents/triage-labels.md`의 `ready-for-agent` 조건을 충족한 상태입니다.
