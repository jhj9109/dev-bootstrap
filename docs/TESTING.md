# 회귀 검증과 실기기 확인

## Phase 0 기준 결과

2026-11-24, 리비전 `44c15d5`, Linux x86_64, Bash 5.2.37, Git 2.56.1에서 기준 검사를 실행했다. 셸 파일별 문법 검사와 7개 테스트 스크립트가 모두 종료 코드 0으로 끝났다. 각 스크립트가 PASS에 도달했다. 표의 단위는 테스트 스크립트다.

| tests/ 아래 파일 | 확인한 동작 |
|---|---|
| test_cli.sh | help, 잘못된 명령, 대화형 종료, doctor의 HOME 보존. doctor 자체의 성공은 요구하지 않는다. |
| test_config_atomic_and_ssh_doctor.sh | 잘못된 설정의 부분 반영 방지, 지운 필드 초기화, 모의 SSH 응답의 사용자·문구·종료 코드 검증 |
| test_iterm_progress.sh | 모의 Darwin/curl/ditto로 설치 단계·다운로드 옵션·재실행·다운로드 실패 확인 |
| test_menu_reload.sh | 실행 중 외부에서 편집한 계정 설정을 같은 메뉴 프로세스에서 다시 읽어 Git에 반영 |
| test_phase2.sh | 실제 임시 Git 설정의 global/local 범위, 두 SSH 프로필과 기존 키·설정·권한 보존 |
| test_phase3.sh | 모의 nvm/uv 조회, 버전·옵션 검증, .zshrc 중복 방지와 기존 파일 보존 |
| test_phase4.sh | Workspace 재실행, file URL로 복제, remote 충돌 거부, 네트워크 설치를 끈 all 두 번 실행 |

T02에서 추가한 `test_registry.sh`는 임시 저장소의 모듈 조회, Workspace 반환 코드, 등록 오류와 외부 링크 거부, 실패 시 HOME 보존을 검사한다.

T03의 `test_runner.sh`는 등록한 모의 모듈의 훅마다 반환 값을 주입하고 호출 순서, 최종 상태, 원본 코드, 셸 변수와 작업 디렉터리 격리를 확인한다. `test_workspace_runner.sh`는 임시 HOME에서 CLI와 메뉴 9번 각각의 최초 생성과 재실행을 확인한다. 기존 파일이나 부모 링크를 만났을 때 mkdir 호출이 0회인지, 경로 오류는 2로, 기존 적용 함수의 사후 검사 실패와 등록된 verify 훅의 실패는 각각 5로 종료하는지 검사한다.

T04는 임시 저장소에서 시스템 iTerm2 조회 함수를 교체해 호스트의 설치 상태를 격리한다. 다운로드 정책, 설치 도구 없이 건너뛰기, 부모 링크와 기존 파일 보존, 부분 복사 실패 후 재실행, verify 실패와 CLI 종료 코드를 검사한다. Phase 4 회귀 테스트는 all에서 활성화한 iTerm2의 SKIPPED 상태도 확인한다.

T05의 `test_git_runner.sh`는 임시 HOME과 연결된 Git worktree에서 global/local 작성자 설정을 확인한다. 일치하면 쓰기 0회, 불일치하면 두 키를 확인한 뒤 적용한다. 잘못된 저장소와 상충하는 범위 옵션, 진단 실패, 적용 도중 실패, 사후 검증 실패의 종료 코드를 검사한다. 메뉴 재로딩과 all 회귀 검사에서도 Git Runner 상태를 확인한다.

T06의 `test_shell_runner.sh`는 v1 템플릿과 실제 로더 줄을 검사하고, 정상 재실행 전후의 파일 내용·inode·수정 시간을 비교한다. 임시 HOME에서 marker만 남은 파일 복구, 중복·편집 파일과 부모 링크 보존, 읽기·복사·교체·사후 검증 실패와 재시도를 확인한다. 실행 여부를 기록하는 .zshrc와 nvm fixture로 진단이 사용자 코드를 실행하는지도 검사한다. Phase 3 테스트는 Node·uv Python의 설치 경로와 이미 설치된 경로에서 Shell Runner 호출을 확인한다.

T07의 `test_node_runner.sh`는 임시 HOME에 모의 nvm을 설치하고 다운로드·설치·use·alias 호출 순서를 기록한다. 부분 버전과 정확한 버전, alias 및 Shell 단독 복구, 조회 오류·Shell 충돌 시 변경 0회, 설치·alias·검증 실패를 검사한다. 모의 nvm은 로딩할 때 작업 디렉터리와 셸 변수를 바꿔 각 훅이 독립적으로 `--no-use`를 사용하는지 확인한다. 메뉴 5번과 all도 같은 Runner를 통과한다.

## 재현

Git 작업 트리의 루트에서 아래 명령을 실행한다. 다른 디렉터리에서는 스크립트의 경로를 지정한다.

```bash
./scripts/verify.sh
```

[검증 스크립트](../scripts/verify.sh)가 추적 중이거나 Git에서 무시하지 않는 신규 `.sh` 파일을 문법 검사한다. `tests/` 아래에서 이름이 `test_*.sh`인 파일은 하위 디렉터리까지 찾아 개별 Bash 프로세스에서 실행한다. 각 테스트에는 임시 HOME과 비운 환경을 제공하고 PATH만 계승한다. Git은 시스템 설정과 대화형 인증을 끄고 file 프로토콜만 허용한다. 네트워크를 사용하는 외부 도구는 테스트 fixture에서 대체한다. 실패 메시지의 파일과 종료 코드를 확인한다.

T01부터 `test_cli.sh`와 `test_menu_reload.sh`는 `setup.sh`와 `bootstrap.sh`를 각각 실행한다. 두 진입점의 도움말, 잘못된 명령·옵션의 종료 코드 2, 메뉴 종료 및 설정 재로딩을 확인한다.

향후 디렉터리 이동 시 문법 검사 대상도 갱신한다. 모의 명령은 정상 반환뿐 아니라 실패·비정상 출력도 주입한다. 설치가 필요한 상태와 진단 명령 실패를 각각 만들고, apply 호출 기록과 HOME 내용·권한을 비교한다. 단계별 추가 검사의 완료 기준은 [이전 계획](REFACTORING_PLAN.md)에 있다.

## Intel iMac 수동 검사

교육장 장비에서 사용자가 승인한 테스트 계정과 별도 HOME을 사용한다. 설치와 실제 인증은 운영자와 일정을 정한 뒤 실행한다.

1. macOS·CPU·/bin/bash 버전과 Xcode CLI 경로를 기록한다. 기본 Bash 3.2로 문법 검사, 전체 오프라인 테스트, 메뉴와 설정 재로딩을 확인한다.
2. v2 구현 후 classroom 및 minimal 계획을 비교한다. dry-run 전후 .ssh, .gitconfig, .zshrc와 Workspace의 내용·권한을 비교한다.
3. SSH 키를 보호한 상태로 등록하고 올바른 계정과 잘못된 계정의 doctor 결과를 비교한다. gh 경로는 별도 계정 fixture로 확인한다.
4. 실제 Node·Python 버전, 새 zsh 세션의 경로, iTerm2 실행, 저장소 origin을 확인한다. 동일 설정으로 다시 실행해 기존 파일과 키가 보존되는지 점검한다.
5. 설치 중단과 복구, 초기화 후 개인 설정·저장소 목록 복원을 점검한다. 결과에는 OS, 선택 프로필, 성공·실패 단계만 남기고 인증 자료는 제외한다.

이번 Linux 실행에서 실기기 설치·Bash 3.2·외부 인증은 미검증이다. 기존 시험의 추가 배경은 [테스트 리뷰 가이드](reviews/TEST_REVIEW_GUIDE.md)에 있다.
