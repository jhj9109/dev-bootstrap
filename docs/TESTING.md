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

T08의 `test_python_runner.sh`는 임시 HOME의 모의 uv·인터프리터·빌드 도구로 방식별 설치와 SKIPPED, Shell 단독 복구, 조회 오류 시 쓰기 0회, 실제 버전 불일치 및 CLI 코드 1·2·3·5를 확인한다. Source 설치 도중 실패한 뒤 임시 파일 정리와 재시도를 검사한다. 기존 설치와 링크 보존, 배치 전후 검증 실패, 메뉴 6번과 all 경로를 포함한다.

T09의 `test_github_runner.sh`는 격리된 HOME과 모의 ssh·ssh-keygen·gh를 사용한다. SSH 쌍의 지문, 두 프로필의 설정, 공개키 복구 실패와 재시도, 설정 검증 실패 후 원본 복원, SKIPPED 안내, doctor의 계정 판정과 출력 제한을 검사한다. gh 미로그인·계정 불일치·조회 오류, 모의 대화형 로그인, 사용자 helper 보존 및 CLI 코드 1·2·3·4·5도 확인한다. 테스트에서 GitHub에 인증하거나 접속하지 않는다.

## Phase 2 완료 판정

T10의 `test_repository_runner.sh`는 실제 로컬 Git 저장소 두 개를 file 전송으로 복제한다. 등록된 check와 verify만 실행해 Workspace 생성이 0회임을 확인한다. CLI와 메뉴 10번으로 목록 복원·재실행, 기존 파일·origin·설정 보존, 연결된 worktree, 명시 목적지와 심볼릭 링크 거부를 검사한다. Git 호출에 실패를 주입해 원격 미설정과 조회 오류를 구분하고, 실패한 복제본의 정리·재시도 및 배치 전후 검증을 확인한다.

| 작업 | Linux에서 확인한 범위 | Intel iMac에서 확인할 항목 |
|---|---|---|
| T04 iTerm2 | 모의 Darwin·curl·ditto로 최초 적용, 재실행, 중단과 검증 실패 | 배포 파일 다운로드, 실제 앱 번들의 복사와 실행 |
| T05 Git | 실제 Git의 global/local 설정과 연결된 worktree에서 재실행·범위 보존, 쓰기 및 조회 실패 주입 | 기본 탑재 Git에서 같은 범위와 종료 코드 |
| T06 Shell | 임시 HOME의 실제 파일로 로더·권한·사용자 편집 보존, 파일 연산·검증 실패 주입 | 새 zsh 세션에서 로더 실행과 PATH |
| T07 Node | 모의 nvm의 부분·정확 버전, alias 복구, 조회·설치·검증 실패 | nvm 설치 및 실제 Node 버전과 default alias |
| T08 Python | 모의 uv·빌드 도구로 버전 변경, 미설치·조회 실패 구분, 빌드 재시도와 검증 실패 | uv 관리 인터프리터 실행, Xcode CLI로 소스 빌드 |
| T09 GitHub | 모의 ssh·ssh-keygen·gh로 키 보존·계정 판정·인증 실패, 실제 임시 Git helper 설정 검사 | 승인된 계정의 키 등록, SSH·gh 인증과 macOS credential helper |
| T10 Repository | 실제 Git clone/remote와 파일 기반 URL 재작성, 선택 프로필 전달, 목록 충돌·오류 처리 | 교육장 초기화 후 실제 목록 복원과 origin 확인 |

Phase 2의 자동 완료 기준은 기존 명령·메뉴 회귀, 동일 목표 재적용, Node·Python의 다른 버전 요청, 진단 및 사후 검증 실패, clone/remote 옵션과 거부 동작으로 확인했다. 기본 Bash 3.2, 실제 설치와 외부 인증은 T21 실기 점검에 남아 있다.

## Phase 3 설정

T11의 `test_config_registry.sh`는 임시 복제본에 모듈을 추가해 기본값 → defaults.conf → profiles.conf 우선순위, 빈 값·공백·개행·셸 특수문자의 왕복, 삭제한 값의 초기화를 확인한다. 공통·모듈 후보값 오류, 설정 파일 로드 실패, 기본값 누락과 훅 실패를 주입하고 마지막 정상 설정의 모든 키를 비교한다. 잘린 레코드·잘못된 키·중복 키·여분 바이트와 스칼라 제약을 검사하고 CLI와 메뉴에서 같은 검증이 적용되는지 확인한다. `test_registry.sh`는 공통 키, 셸·Runner·Registry 예약 변수, 접두사가 겹치는 두 모듈의 키 충돌을 두 진입점에서 검사한다.

T12의 `test_environments.sh`는 같은 계정의 classroom/minimal 선택, CLI 우선순위, 메뉴 재로딩, 환경 파일이 없는 레거시 classroom과 명시한 빈 배열을 검사한다. 잘못된 ID·중복·희소 배열·잘린 스냅샷을 주입한 뒤 전체 설정을 비교한다. `test_repository_runner.sh`는 같은 계정에서 minimal을 선택하면 잘못된 복제 목록이 있어도 Git·GitHub 단계가 성공하는지 확인한다. 기존 `test_phase4.sh`는 세 레거시 설치 플래그를 끄고 다시 켠 실제 `all` 경로를 검증한다.

## Phase 3 완료 판정

T11의 등록 훅과 T12의 환경별 목록·옵션 우선순위·레거시 `INSTALL_*` 검사를 전체 회귀에 포함한다. T13의 `test_accounts.sh`는 두 개인 파일을 함께 읽어 필드 생략·삭제·빈 값의 차이, 비계정 설정의 격리, 계정 선택 시 검증을 확인한다. 소싱 실패와 배열형 계정 필드를 주입한 뒤 이전 스칼라 및 활성 배열 전체를 비교한다. 메뉴 테스트는 실행 중 개인 파일을 수정해 실제 Git 작성자를 갱신하며 GitHub Runner 테스트는 accounts.conf 단독으로 SSH·gh 경로를 확인한다.

## 재현

Git 작업 트리의 루트에서 아래 명령을 실행한다. 다른 디렉터리에서는 스크립트의 경로를 지정한다.

```bash
./scripts/verify.sh
```

[검증 스크립트](../scripts/verify.sh)가 추적 중이거나 Git에서 무시하지 않는 신규 `.sh` 파일을 문법 검사한다. `tests/` 아래에서 이름이 `test_*.sh`인 파일은 하위 디렉터리까지 찾아 개별 Bash 프로세스에서 실행한다. 각 테스트에는 임시 HOME과 비운 환경을 제공하고 PATH만 계승한다. Git은 시스템 설정과 대화형 인증을 끄고 file 프로토콜만 허용한다. 네트워크를 사용하는 외부 도구는 테스트 fixture에서 대체한다. 실패 메시지의 파일과 종료 코드를 확인한다.

T01부터 `test_cli.sh`와 `test_menu_reload.sh`는 `setup.sh`와 `bootstrap.sh`를 각각 실행한다. 두 진입점의 도움말, 잘못된 명령·옵션의 종료 코드 2, 메뉴 종료 및 설정 재로딩을 확인한다.

향후 디렉터리 이동 시 문법 검사 대상도 갱신한다. 모의 명령은 정상 반환뿐 아니라 실패·비정상 출력도 주입한다. 설치가 필요한 상태와 진단 명령 실패를 각각 만들고, apply 호출 기록과 HOME 내용·권한을 비교한다. 단계별 추가 검사의 완료 기준은 [이전 계획](REFACTORING_PLAN.md)에 있다.

## Bash 버전별 전체 검증

이미 준비된 두 Bash 실행 파일의 경로를 지정한다. 아래 경로는 예시다. 매트릭스는 설치나 다운로드 없이 실행된다.

```bash
BASH5_BIN=/opt/bash5/bin/bash BASH32_BIN=/opt/bash32/bin/bash ./scripts/verify-matrix.sh
```

각 행은 실행 파일에서 읽은 버전을 검사하고 임시 PATH의 첫 `bash`를 해당 파일에 연결한다. `/usr/bin/env bash` 진입점과 그 안에서 호출한 `bash`의 버전·실행 파일을 대조한 뒤 기존 `verify.sh` 전체를 실행한다. 임시 HOME의 테스트에도 같은 PATH를 전달한다.

각 행의 `PASS`는 전체 검증 성공, `FAIL`은 호출 경로 확인 또는 검증 실패, `NOT RUN`은 경로 누락·실행 불가·버전 불일치다. 한 행이 실패해도 다른 행을 시도하며 두 행이 모두 통과해야 종료 코드가 0이다. Linux용 Bash 3.2 결과와 아래 실기기 결과는 따로 기록한다.

## Intel iMac 수동 검사

교육장 장비에서 사용자가 승인한 테스트 계정과 별도 HOME을 사용한다. 설치와 실제 인증은 운영자와 일정을 정한 뒤 실행한다.

1. macOS·CPU·/bin/bash 버전과 Xcode CLI 경로를 기록한다. 기본 Bash 3.2로 문법 검사, 전체 오프라인 테스트, 메뉴와 설정 재로딩을 확인한다.
2. v2 구현 후 classroom 및 minimal 계획을 비교한다. dry-run 전후 .ssh, .gitconfig, .zshrc와 Workspace의 내용·권한을 비교한다.
3. SSH 키를 보호한 상태로 등록하고 올바른 계정과 잘못된 계정의 doctor 결과를 비교한다. gh 경로는 별도 계정 fixture로 확인한다.
4. 실제 Node·Python 버전, 새 zsh 세션의 경로, iTerm2 실행, 저장소 origin을 확인한다. 동일 설정으로 다시 실행해 기존 파일과 키가 보존되는지 점검한다.
5. 설치 중단과 복구, 초기화 후 개인 설정·저장소 목록 복원을 점검한다. 결과에는 OS, 선택 프로필, 성공·실패 단계만 남기고 인증 자료는 제외한다.

T11에서는 Linux에서 Bash 5.2.37과 Apple 공개 소스를 Linux용으로 빌드한 Bash 3.2.57로 전체 검증을 실행했다. Intel iMac 기본 Bash와 실제 설치·외부 인증은 수동 확인 대상으로 남아 있다. 기존 시험의 추가 배경은 [테스트 리뷰 가이드](reviews/TEST_REVIEW_GUIDE.md)에 있다.
