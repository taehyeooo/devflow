# devflow

1인 개발에서 **매일 반복하던 작업**을 Claude Code 플러그인으로 묶었습니다.
여행 영상 → 일정 앱 [Trova](https://github.com/Trovapp/trova-backend)를 만들며 손으로 수십 번 반복한 절차를 그대로 옮겼습니다.

| 구성 | 종류 | 하는 일 |
|---|---|---|
| `commit-guard` | 훅(PreToolUse) | Claude가 `git commit` 하기 직전에 메시지 형식·AI 서명 금지·커밋하면 안 되는 문자열(임시 QA 토큰 등)을 확인하고 어기면 막음 |
| `deploy` | 스킬 + 스크립트 | 빌드 → 진행 중 작업 확인 → 전송·해시 비교 → 백업 → 교체·재시작 → UP 대기 → 배포 후 보안 확인 → 기록 |
| `qa-sim` | 스킬 + 스크립트 | iOS 시뮬레이터 QA 준비/원복, 좌표 탭+캡처, 글자 크기 바꾸기, 테스트 데이터 개수 저장·비교, 외부 API 사용량 확인 |
| `local-server` | 스킬 + 스크립트 | 기준 커밋으로 맞추기 → 서버 끄기 → 빌드 → .env 불러와 실행 → health UP 대기 |
| `work-record` | 스킬 + 스크립트 | 브랜치의 사실(커밋·테스트 수·최근 배포/QA 시간)을 모아 범위 → 방법 비교 → 확인 틀로 작업 기록 초안 |
| `report` | 스크립트 | 배포·QA 기록 요약 — 횟수, 걸린 시간(중앙값·평균), 단계별 평균 |

## 설치
```
/plugin marketplace add taehyeooo/devflow
/plugin install devflow@devflow
```

## 설정
서버 주소·키 경로·DB 조회 명령은 **공개 레포에 올리지 않도록 레포 밖**에 둡니다.
`~/.config/devflow/<origin 레포 이름>.json` (worktree에서도 같은 파일을 찾음). 예시: [`examples/config.example.json`](examples/config.example.json)

## 사용 기록
`~/.config/devflow/usage.log`, 배포는 `deploy.log`에 시간·결과가 남습니다. 실제 사용 기록은 [docs/usage-trova.md](docs/usage-trova.md).
