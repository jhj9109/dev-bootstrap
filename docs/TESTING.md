# 회귀 검증과 실기기 확인

## Phase 0 기준 결과

2026-11-24, 리비전 `44c15d5`, Linux x86_64, Bash 5.2.37, Git 2.56.1에서 아래 명령을 실행했다. 셸 파일별 문법 검사와 7개 테스트 스크립트가 모두 종료 코드 0으로 끝났다. 각 스크립트가 PASS에 도달했다. 표의 단위는 테스트 스크립트다.

| tests/ 아래 파일 | 확인한 동작 |
|---|---|
| test_cli.sh | help, 잘못된 명령, 대화형 종료, doctor의 HOME 보존. doctor 자체의 성공은 요구하지 않는다. |
| test_config_atomic_and_ssh_doctor.sh | 잘못된 설정의 부분 반영 방지, 지운 필드 초기화, 모의 SSH 응답의 사용자·문구·종료 코드 검증 |
| test_iterm_progress.sh | 모의 Darwin/curl/ditto로 설치 단계·다운로드 옵션·재실행·다운로드 실패 확인 |
| test_menu_reload.sh | 실행 중 외부에서 편집한 계정 설정을 같은 메뉴 프로세스에서 다시 읽어 Git에 반영 |
| test_phase2.sh | 실제 임시 Git 설정의 global/local 범위, 두 SSH 프로필과 기존 키·설정·권한 보존 |
| test_phase3.sh | 모의 nvm/uv 조회, 버전·옵션 검증, .zshrc 중복 방지와 기존 파일 보존 |
| test_phase4.sh | Workspace 재실행, file URL로 복제, remote 충돌 거부, 네트워크 설치를 끈 all 두 번 실행 |

## 재현

저장소 루트에서 Bash로 실행한다. 각 테스트가 임시 HOME을 준비한다. 복제 테스트의 HTTPS 주소는 로컬 Git fixture로 치환된다. 테스트마다 별도 프로세스로 실행해야 설정과 PATH가 섞이지 않는다.

```bash
(
  set -e
  for file in bootstrap.sh setup.sh lib/*.sh modules/*.sh modules/auth/*.sh tests/*.sh; do
    bash -n "$file"
  done
  for file in tests/test_*.sh; do
    GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0 bash "$file"
  done
)
```

향후 디렉터리 이동 시 문법 검사 대상도 갱신한다. 모의 명령은 정상 반환뿐 아니라 실패·비정상 출력도 주입한다. 설치가 필요한 상태와 진단 명령 실패를 각각 만들고, apply 호출 기록과 HOME 내용·권한을 비교한다. 단계별 추가 검사의 완료 기준은 [이전 계획](REFACTORING_PLAN.md)에 있다.

## Intel iMac 수동 검사

교육장 장비에서 사용자가 승인한 테스트 계정과 별도 HOME을 사용한다. 설치와 실제 인증은 운영자와 일정을 정한 뒤 실행한다.

1. macOS·CPU·/bin/bash 버전과 Xcode CLI 경로를 기록한다. 기본 Bash 3.2로 문법 검사, 전체 오프라인 테스트, 메뉴와 설정 재로딩을 확인한다.
2. v2 구현 후 classroom 및 minimal 계획을 비교한다. dry-run 전후 .ssh, .gitconfig, .zshrc와 Workspace의 내용·권한을 비교한다.
3. SSH 키를 보호한 상태로 등록하고 올바른 계정과 잘못된 계정의 doctor 결과를 비교한다. gh 경로는 별도 계정 fixture로 확인한다.
4. 실제 Node·Python 버전, 새 zsh 세션의 경로, iTerm2 실행, 저장소 origin을 확인한다. 동일 설정으로 다시 실행해 기존 파일과 키가 보존되는지 점검한다.
5. 설치 중단과 복구, 초기화 후 개인 설정·저장소 목록 복원을 점검한다. 결과에는 OS, 선택 프로필, 성공·실패 단계만 남기고 인증 자료는 제외한다.

이번 Linux 실행에서 실기기 설치·Bash 3.2·외부 인증은 미검증이다. 기존 시험의 추가 배경은 [테스트 리뷰 가이드](reviews/TEST_REVIEW_GUIDE.md)에 있다.
