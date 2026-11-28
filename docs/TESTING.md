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

## T14 셸 이관

`bash tests/test_shellenv.sh`는 임시 HOME에 v1 템플릿과 사용자 .zshrc를 두고 최종 교체 실패와 재시도를 시험한다. 두 Bash는 이관 함수를 실행하고, 별도 `zsh -f` 프로세스가 실제 .zshrc를 읽어 활성 순서·반복 로드·PATH·비활성 조각 제외를 확인한다. 잘못된 목록과 링크는 첫 조각 실행 전에 거부해야 한다. zsh가 없으면 이관 거부와 원본 보존만 검사하고 실제 zsh 결과는 `NOT RUN`으로 출력한다.

## T15 및 Phase 4 검증

`tests/test_shell_activation.sh`는 실제 CLI로 v1을 이관하고 classroom → minimal → 개별 uv·Node 설치를 실행한다. 새 zsh에서 .zshrc를 두 번 읽은 후 nvm 함수·NVM_BIN·Node와 uv 명령 경로를 확인한다. 설치 파일과 실행 파일은 로컬 fixture다. 목록 및 관리 조각 교체 실패 후 재시도, 사용자 편집 내용과 비활성 파일 보존, Source 환경의 PATH도 검사한다. Bash 매트릭스가 실행하는 전체 회귀에는 기존 메뉴, CLI, 레거시 설정과 all 재실행이 포함된다. v2 설치·이관의 구문 검사와 이 테스트에는 실제 zsh가 필요하다.

## T16 실행 계획

`tests/test_planner.sh`는 임시 저장소에 복수 선행 모듈이 있는 그래프를 등록하고 두 CLI 진입점의 계획 출력과 종료 코드를 대조한다. 정상 사용자 순서, 누락·역순·중복·미등록 ID·자기 참조·순환, 실제 Node·Python 설치 방식별 Shell 관계와 Repository의 Workspace 관계를 검사한다. 매 요청 전후에 기존 로더·활성 목록·사용자 파일·링크·권한을 포함한 HOME 아카이브를 비교하고, 실행 훅과 설치·인증 도구 호출 기록이 비어 있는지 확인한다. 빈 배열에 대해서는 실제 `all`도 같은 HOME을 보존해야 한다.

## T17 실행 결과와 선행 상태

`tests/test_plan_runner.sh`는 다이아몬드 의존 그래프에 check·apply·verify 실패를 주입한다. 호출 기록으로 전이 차단, 독립 모듈의 완료, 단일 대상의 선행 검사 횟수, 두 번째 실행의 SKIPPED를 확인한다. 읽기 전용 검사와 차단된 단일 적용 전후에는 임시 HOME 아카이브를 대조한다. 빈 계획, 순환·옵션 오류 코드 2, Python 방식·버전 재정의, Shell 상태 변경 후 중첩 적용 방지, Git 로컬 범위도 포함한다.

`tests/test_repository_runner.sh`는 Workspace 생성 시 목록 파일을 교체해 Repository의 검사·적용·검증이 처음 확정한 두 저장소를 끝까지 사용하는지 확인한다. 생성 호출이 한 번인지, 기존 개별 복제 명령이 계속 기본 목적지를 준비할 수 있는지도 검사한다.

## T21 Intel iMac 수동 검사 — 진행 중

교육장 제공 결과는 기준 커밋 `18c05d7`, iMac20,1(x86_64), macOS 26.5.2(25F84), 시스템 Bash 3.2.57 및 zsh 5.9에서 얻었다. 문법 검사 59개와 회귀 테스트 26개가 통과했고 minimal·classroom 각각 plan과 dry-run 출력이 일치했다. Git·Workspace는 SKIPPED, Shell은 CHANGE_NEEDED였다. 관리 SSH 파일이 없는 상태에서 `check github --profile personal --method ssh`가 기존 OrbStack Include를 충돌로 판정했다(NEEDS_ACTION, check 훅 4).

`tests/test_orbstack.sh`는 임시 HOME에 교육장의 단일 Host orb 구성을 재현한다. 시스템 OpenSSH의 `-G`로 orb의 유효 설정 전체를 전후 대조하고, 두 GitHub 별칭의 목적지·포트·키·프록시·known_hosts 격리를 검사한다. OpenSSH는 Include의 물결표를 로그인 사용자의 홈으로 확장하므로 이 비교에서만 두 Include를 임시 경로로 치환한다. configure·check·재실행, minimal all, 모의 원격 응답을 쓰는 doctor, 게시 직전 Include 내용 변경을 검사한다. 이 비교는 사용자 SSH 설정에 한정된다. iMac의 시스템 SSH 정책을 포함한 유효 설정과 실제 원격 인증은 현장 재검증 대기다.

수정본을 전용 iMac 계정의 터미널에서 같은 check로 재검사한다. 새 키가 필요한 상태는 CHANGE_NEEDED, 적용 후 같은 check와 configure는 SKIPPED가 기대값이다. 승인 후 공개키를 등록하고 doctor로 원격 계정까지 확인한다. 실제 설치·새 zsh·교육장 초기화 후 복원도 아래 절차에 따라 결과를 확보해야 한다.

교육장 운영자가 승인한 전용 macOS 테스트 사용자로 로그인한다. 실제 SSH와 gh는 사용자 홈·키체인·호스트 키·원격 계정에도 접근하므로 HOME 변수만 바꿔 운영 계정에서 시험하지 않는다. Git, Xcode CLI, curl, ditto, zsh, 테스트 저장소 읽기 권한, 기관이 확인한 GitHub 호스트 키 및 다운로드 가능한 네트워크를 준비한다. gh 방식에는 사전 설치한 gh가 필요하다. 일반 사용자 데이터 초기화는 이 절차에 포함하지 않는다.

| 단계 | 명령과 기대 결과 | 실패 시 확인 |
|---|---|---|
| 장비·소스 확인 | `sw_vers`, `uname -m`, `/bin/bash --version`, `xcode-select -p`, `git rev-parse HEAD`, `./setup.sh doctor`. x86_64, 기본 Bash 3.2, CLI 도구 경로를 기록한다. | OS·CPU와 도구 누락, 사용자 디렉터리 권한 |
| 오프라인 회귀 | 기본 Bash가 PATH의 첫 bash인지 확인하고 `PATH=/bin:/usr/bin:$PATH /bin/bash scripts/verify.sh`를 실행한다. 설치된 두 Bash가 있으면 위 매트릭스도 실행한다. | 실패한 테스트 이름과 셸 버전, 실제 zsh 사용 여부 |
| 계획과 사용자 파일 | `./setup.sh plan --environment minimal`, 같은 옵션의 `all --dry-run` 출력을 비교한다. classroom으로 반복한다. 전후 .gitconfig·.zshrc·.ssh와 Workspace의 내용·권한·링크를 로컬에서 대조한다. | 모듈 순서, 실제 환경 파일, 계정 선택, 예상 밖 변경 |
| 인증과 복원 | 사용자 설명서 순서대로 SSH 설정 → 공개키 등록 → `./setup.sh doctor github --profile personal` 실행. gh는 승인된 별도 계정으로 검사한다. 목록에 테스트 저장소를 두고 all을 실행한다. | 로컬 설정 성공과 원격 인증을 구분해 호스트 키·사용자명·권한·origin 확인 |
| 설치와 재실행 | 새 zsh에서 `nvm current`, `node --version`, `uv python find --managed-python` 확인. Source 설치 시 지정 prefix의 python 실행. iTerm2 앱을 직접 연다. 같은 all 재실행에서 SKIPPED와 사용자 파일 보존 확인. | PATH·active.list, Xcode 빌드 로그, 파일 소유권, Gatekeeper 및 배포 정책 |
| 복구 | 전용 계정에서 설치 중단 후 같은 명령을 재시도한다. 운영자가 승인한 교육장 초기화 이후 개인 설정·저장소 목록으로 복원을 반복한다. | 잔여 staging·잠금과 기존 사용자 편집을 확인하고 자동 덮어쓰기 여부 점검 |

기록에는 날짜, 장비·셸 버전, 커밋, 명령, 종료 코드와 기대 결과의 차이만 남긴다. 개인키·토큰·계정 파일·인증 출력 원문은 첨부하지 않는다. 실제 장비 결과가 있어야 T21을 완료로 표시한다.

## T18 및 Phase 5

`test_registry_views.sh`는 임시 모듈의 ID·이름, 특수 명령 도움말, 0~11 고정 메뉴와 추가 번호를 확인한다. 조회·메뉴 종료 시 훅 호출이 없고 특수 명령의 빈 문자열·공백·글로브·옵션 인자와 종료 코드가 보존되는지 검사한다. Phase 5의 계획 오류·dry-run 무변경은 planner fixture, 전이 차단·독립 모듈 완료는 plan_runner fixture에서 확인한다. 기존 메뉴 재로딩·복구·옵션 오류와 SSH 공개키 안내는 전체 회귀에 포함한다.

## T19 및 Phase 6 확장성 검증

`bash tests/test_module_extension.sh`는 현재 작업 트리의 실행 파일과 공개 설정을 임시 디렉터리에 복사한다. 이 복제본에만 [모듈 작성 규약](MODULE_CONTRACT.md)에 따라 버전 파일을 관리하는 `sample`과 그 모듈에 의존하는 `sample_cache`를 추가한다. 복제본의 `minimal.conf`에 두 모듈과 기존 `workspace`를 순서대로 활성화한다. 별도의 임시 HOME에서 `bootstrap.sh`를 실행하고, 환경 이름 거부 검사 외에는 `--environment minimal`을 지정한다.

| Phase 6 확인 항목 | 판정 근거 |
|---|---|
| 공통 파일 동일성 | 모듈 추가 전 보관한 두 진입점과 `core/`, `lib/` 전체를 복제본과 `diff -r`로 대조한다. fixture 작성 직후와 실패·재시도를 마친 뒤에도 파일 목록과 내용이 같아야 한다. |
| 탐색과 조회 | list와 help에서 등록한 ID·표시 이름을 찾고, 메뉴에 표시된 번호를 읽어 실제로 선택한다. plan과 all --dry-run의 출력이 같고 세 모듈의 순서와 의존 관계가 정확해야 한다. 조회 중 예제 실행 훅 호출은 0회다. |
| 목표 적용과 재실행 | 기본값 1에서 check는 코드 1과 CHANGE_NEEDED를 반환하며 HOME을 보존한다. 첫 apply는 check → apply → verify 순서와 실제 파일 내용으로 확인한다. 두 번째 apply에서는 check만 호출하고 SKIPPED를 반환하며 같은 파일·inode를 보존한다. 환경 목표를 2로 바꾼 뒤 메뉴로 재적용하고 check로 확인한다. |
| 입력·실행 실패 | 숫자가 아닌 설정과 지원하지 않는 옵션은 코드 2로 거부하고 HOME을 보존한다. PATH의 모의 mv가 23을 반환하면 apply에서, 쓰기를 누락하고 0을 반환하면 verify에서 실패해야 한다. 두 경우 모두 CLI 코드 1, 원본 훅 코드, 직전 버전 보존 및 임시 파일 정리를 확인한다. |
| 의존성과 복구 | 단일 apply는 미충족 선행을 읽기 전용으로 확인한다. 일괄 실행에서 버전 파일의 심볼릭 링크로 check가 실패하면 sample_cache의 훅은 호출되지 않고 BLOCKED가 되며, 뒤의 독립 workspace는 SUCCESS가 된다. 링크를 정리하고 다시 실행하면 버전 3과 캐시 디렉터리가 생성되고, 다음 일괄 실행은 세 모듈 모두 SKIPPED다. |

### 확장 범위와 제약

| 원인 | 새 모듈 작성자에게 미치는 영향 |
|---|---|
| 설정 로더의 `config_validate_environment`가 환경 이름을 `classroom`과 `minimal`로 제한한다. | 새 모듈과 설정 키는 기존 환경 파일에서 활성화할 수 있다. 같은 내용의 `extension.conf`를 추가해도 `--environment extension plan`은 코드 2로 종료한다. |
| 범용 CLI의 `parse_options`는 `--version`을 Node와 Python에만 연결한다. | `--keys SAMPLE_VERSION` 등록은 설정 로딩과 검증을 확장한다. `apply sample --version 3`은 코드 2로 종료하므로 예제 모듈의 버전 목표는 환경 파일에서 지정한다. |
| 모듈 규약의 verify는 Runner가 변경 후 호출하는 훅이다. | 사후 검증 결과는 apply 요약의 verify 단계에서 확인한다. 성공을 반환한 쓰기가 실제 목표를 반영하지 못하는 경우도 이 단계에서 검출한다. |

## T20 문서 명령 재현

Linux의 임시 복제본에는 Git 추적 파일만 복사하고 빈 환경·임시 HOME·가상 계정값·file 전용 Git 전송을 사용했다. README의 설정 예시 복사, list/help, minimal plan과 같은 옵션의 all --dry-run 출력 일치, check workspace(1) → apply workspace(0) → check workspace(0)를 확인했다. configure git의 작성자, configure shell 이후 기존 .zshrc 줄 보존과 실제 zsh의 두 번 로드, 메뉴 11→0도 확인했다. 기본 doctor는 Linux와 xcode-select 부재를 보고하고 1로 종료했다.

전체 매트릭스는 install node/python/iterm과 configure github·doctor github를 모의 배포·인증 도구로, repo clone/remote와 목록 복원을 로컬 Git 저장소로 검사한다. 이 결과가 다루는 범위는 명령 분기·파일 보존·실패 후 재시도다. 실제 배포 서비스, macOS 앱 실행과 GitHub 원격 인증은 T21에서 확인한다.

### T21 개인키 지문 재검증

기준 a672b21의 교육장 iMac20,1(Intel x86_64, macOS 26.5.2, Bash 3.2.57, OpenSSH_10.2p1 / LibreSSL 3.3.6)에서 test_orbstack.sh의 GitHub apply가 1로 중단됐다. 실제 Ed25519 공개키와 인접 .pub 없는 개인키를 각각 파일 경로로 검사한 결과와 공개키를 /dev/stdin 경유로 검사한 결과는 모두 종료 0, 동일한 SHA256 지문이었다. 개인키만 /dev/stdin 경유 시 “/dev/stdin is not a key file.”과 종료 255를 반환했다.

ssh_setup은 키 생성 직후 쌍을 검사하므로 이 실패가 게시 전에 apply로 전파됐다. 수정본은 모드 700인 임시 디렉터리에 원본을 가리키는 링크 하나를 만들고 그 경로를 ssh-keygen -l에 전달한다. OpenSSH가 이웃 .pub를 선택할 수 없으며 개인키 복사나 복호화가 필요 없다. tests/test_ssh_fingerprint.sh는 실제 OpenSSH로 일반·암호화 키의 지문, 바꿔 놓은 인접 공개키, 임시 경로 권한, 실패 후 정리와 원본 보존을 검사한다. 교육장에서는 수정 커밋으로 전체 매트릭스와 기존 OrbStack 검사를 재실행한다.

수정본 `0854da5`를 iMac20,1(x86_64), macOS 15.7.5(24G624), OpenSSH_9.9p2 / LibreSSL 3.3.6에서 재검증했다. 임시 HOME과 기본 Bash 3.2.57로 아래 세 명령을 순서대로 실행했고 모두 종료 0이었다.

```bash
/bin/bash tests/test_ssh_fingerprint.sh
/bin/bash tests/test_orbstack.sh
/bin/bash scripts/verify.sh
```

지문 검사의 불일치·잘못된 입력 오류는 음성 테스트에서 기대한 출력이다. OrbStack fixture의 설정 보존과 GitHub 프로필 격리를 확인했고 전체 검사는 문법 61개·회귀 스크립트 28개를 통과했다. 교육장 macOS 26.5.2·OpenSSH 10.2p1에서의 수정본 실행과 실계정 인증·초기화 후 복원은 대기 중이다.

### 2026-11-28 로컬 읽기 전용 점검

기준 `dd062dc`, Intel x86_64 macOS 15.7.5(24G624), 기본 Bash 3.2.57, zsh 5.9, OpenSSH 9.9p2 / LibreSSL 3.3.6. 실제 사용자 HOME을 대상으로 기본 personal·ssh 설정에서 조회했다. 사용자 파일 전후의 내용·권한 대조는 미실행이다.

| 명령 | 종료 코드와 관찰 |
|---|---|
| `./setup.sh doctor` | 0. 실패 0, 경고 2(SSH config 없음, PATH에서 Node 없음). Git·curl·Xcode CLI 경로·Workspace 확인. PATH의 python3은 3.9.6이다. |
| `./setup.sh plan --environment ENV`, `./setup.sh all --dry-run --environment ENV` | minimal(4개)·classroom(8개)에서 모두 0. 환경별 두 출력이 바이트 단위로 일치했다. |
| `./setup.sh check MODULE --environment classroom` | workspace와 repository는 0(SKIPPED). 저장소 목록이 없어 복원 대상은 0개였다. git과 github는 각각 1(훅 2). personal 사용자명·이메일 미설정으로 SSH 구성 검사 전 중단됐다. |
| 같은 check의 shell·node·python·iterm | 각각 1. Shell과 iTerm2는 CHANGE_NEEDED. Node와 Python은 Shell 선행 조건으로 BLOCKED여서 자체 훅은 실행되지 않았다. 기본 nvm.sh·사용자 uv 실행 파일이 없었고 PATH에 gh도 없었다. |

승인된 테스트 계정에서 personal 사용자명·커밋 이메일을 로컬 계정 설정에 준비하고 Git·GitHub check를 다시 실행한다. HOME 변경 승인 후 Git 작성자·Shell·SSH 설정을 적용하고 check를 반복한다. 다운로드 승인 후 classroom 목표인 Node 24(nvm), Python 3.12(uv), iTerm2를 적용하고 새 zsh에서 버전과 앱 실행을 확인한다. SSH는 호스트 키를 확인하고 공개키 등록·원격 인증 승인 후 doctor github를 실행한다. 테스트 저장소 목록과 접근 권한이 준비되면 복원과 재실행을 확인한다. gh 방식은 별도 설치·인증 검증이 필요하다. 현재 표준 OrbStack 설정 경로에는 파일이 없어 교육장 설정과의 공존은 미검증이다. 교육장 26.5.2·OpenSSH 10.2p1 재검증, 설치 중단 후 재시도와 초기화 후 복원은 대기다.

### T21 실제 적용 중간 결과

기준 `12549ae`, 로컬 Intel macOS 15.7.5의 classroom·personal. Git과 GitHub의 로컬 검사가 personal 설정을 수락했다. 실제 HOME 적용 승인 후 아래 순서로 확인했다.

| 모듈 | 적용 전 check | apply | 적용 후 check |
|---|---|---|---|
| git | 1 CHANGE_NEEDED | 0 SUCCESS | 0 SKIPPED |
| shell | 1 CHANGE_NEEDED | 0 SUCCESS | 0 SKIPPED |
| github (ssh) | 비대화형 1 NEEDS_ACTION(훅 4), TTY 1 CHANGE_NEEDED | 전용 키 생성 시 사용자의 터미널 패스프레이즈 입력 대기 | 미실행 |

사용자가 로컬 터미널에서 `./setup.sh apply github --environment classroom --profile personal`을 실행해 패스프레이즈를 직접 입력한 뒤 로컬 check를 반복한다. 공개키 등록과 원격 인증은 별도 단계다. Node·Python(uv)·iTerm2 적용 및 새 zsh 실행 검사는 대기다. 사용자 파일 전후의 독립적인 내용 대조는 미실행이다.

### 2026-11-28 실제 인증·설치·저장소 복원

기준 `0904424`, 로컬 Intel macOS 15.7.5, classroom·personal·ssh. 사용자는 SSH 키 구성, 공개키 등록, 공식 GitHub ED25519 호스트 키 지문 대조와 known_hosts 등록, SSH agent 등록을 수행했다. 최초 SSH 인증은 호스트 키 미등록으로 종료 255였다. 등록 후 사용자가 실행한 `./setup.sh doctor github --profile personal --method ssh`에서 대상 계정 인증 성공을 확인했다. 이번 세션에서 로컬 GitHub check는 0 SKIPPED였다. 최초 호스트 키 확인·등록 안내와 exit 255의 원인별 진단을 후속 개선 후보로 기록한다.

| 실제 대상 | 적용 전 check | apply | 적용 후 check / 두 번째 apply | 실행 확인 |
|---|---|---|---|---|
| Node 24 | 1 CHANGE_NEEDED | 0 SUCCESS | 모두 0 SKIPPED | 새 로그인·대화형 zsh에서 nvm current와 node --version 모두 v24.22.3 |
| Python 3.12 (uv) | 1 CHANGE_NEEDED | 0 SUCCESS | 모두 0 SKIPPED | 같은 zsh에서 uv 0.13.10으로 관리 인터프리터를 오프라인 조회하고 직접 실행해 3.12.16 확인 |
| iTerm2 | 1 CHANGE_NEEDED | 0 SUCCESS | 모두 0 SKIPPED | 사용자 Applications의 앱을 열고 iTerm2 프로세스 확인 |
| repository | 1 CHANGE_NEEDED | 0 SUCCESS | 모두 0 SKIPPED | 승인된 테스트 저장소를 personal SSH로 복원, 복제 HEAD 44c15d5 확인 |

각 행은 `./setup.sh check MODULE`, `apply MODULE`, `check MODULE`, `apply MODULE` 순서다. 저장소 검사는 현재 작업 저장소를 대상으로 별도 목록과 빈 Workspace를 사용했다. 첫 시도는 HOME 밖 임시 경로여서 workspace 훅이 2를 반환하고 clone 전에 차단됐다. Documents 아래 전용 임시 경로에서 기존 known_hosts와 agent를 사용해 strict host key checking으로 복원한 후 임시 복제본을 정리했다. 영구 복원 목록은 편집하지 않았다. 교육장 OS·OpenSSH 조합과 OrbStack 공존, 설치 중단 후 재시도 및 초기화 후 복원 등 남은 T21 항목은 대기다.

### T21 classroom 전체 실행과 파일 보존

2026-11-28, 기준 `628f13a`, 로컬 Intel macOS 15.7.5. 실제 HOME과 personal 계정 설정을 사용했다. 기준 커밋의 별도 실행 복사본에 테스트 목록 한 줄(`jhj9109/dev-bootstrap`)과 Documents 아래 빈 임시 Workspace를 지정했다. 기존 작업 저장소와 개인 복원 목록은 그대로 두고 기존 SSH agent와 known_hosts로 복원했다.

| 순서 | 명령 (공통 옵션 `--environment classroom --profile personal --method ssh`) | 종료 코드와 결과 |
|---|---|---|
| 1 | `./setup.sh check` | 1. repository만 CHANGE_NEEDED, 나머지 7개 SKIPPED |
| 2 | `./setup.sh all` | 0. repository 복원 SUCCESS, 나머지 7개 SKIPPED |
| 3 | `./setup.sh check` | 0. 8개 모두 SKIPPED |
| 4 | `./setup.sh all` | 0. 8개 모두 SKIPPED |
| 5 | `./setup.sh check` | 0. 8개 모두 SKIPPED |

각 명령 직후 실행 전 상태와 대조했다. 대상은 .ssh 전체(개인키·공개키·known_hosts 포함), Git 사용자 설정, .zshrc·.zprofile·.zlogin·.zshenv, 관리 셸 설정 디렉터리, nvm 기본 별칭, OrbStack SSH 설정 경로, 원본·실행 복사본의 config 및 원본 .git/config였다. 경로 존재 여부·종류·모드·소유자·그룹, 링크 대상과 일반 파일 내용(SHA-256)을 메모리에서 비교해 차이 0건을 확인했다. 작업 저장소의 fetch/push origin·HEAD·작업 트리 상태도 동일했다. 복원 직후 깨끗한 복제본을 기준으로 이후 세 명령마다 .git 포함 전체 파일과 origin·HEAD·작업 트리 상태가 일치했다. 비교값과 인증 원문은 저장하지 않았다. 임시 Workspace는 검사 후 정리했다.

후속 검증 조건은 다음과 같다.

- Python Source는 정확한 X.Y.Z 버전, 승인된 다운로드와 빌드 시간·공간, Xcode CLI·make·tar 및 충돌 없는 사용자 prefix를 준비한다. 설치 후 해당 prefix의 인터프리터로 버전과 표준 라이브러리를 확인하고 같은 요청을 반복한다.
- gh 인증은 gh가 설치된 승인된 전용 계정과 대화형 로그인 수단이 필요하다. 기존 Git credential helper를 전후 비교하고 gh 방식의 check·apply·doctor와 재실행을 확인한다.
- 설치 중단 복구는 중단 지점과 대상을 미리 정한 전용 계정 또는 격리된 설치 경로에서 수행한다. 중단 전 사용자 파일을 비교 기준으로 확보하고, 중단 후 staging·잠금·부분 설치 상태를 확인한 뒤 같은 명령 재시도와 SKIPPED를 검증한다.

위 세 항목과 교육장 macOS 26.5.2·OpenSSH 10.2p1 및 초기화 후 복원은 미실행이다.

### T21 Python Source 컴파일 중단과 동일 명령 재시도

2026-11-28, 기준 `02aadaf`, Intel macOS 15.7.5. Xcode CLI의 clang, 시스템 make·tar·curl, 여유 공간 415 GiB를 확인했다. 승인된 대상은 CPython 3.12.10과 별도 prefix `~/.local/python-3.12.10`이었다. 시작 전 해당 경로에 파일·링크가 없었고 Source check는 1 CHANGE_NEEDED, 기존 uv 3.12 check는 0 SKIPPED였다.

세 번 모두 `./setup.sh apply python --environment classroom --method source --version 3.12.10`을 실행했다.

| 실행 | 종료 코드 | 검증 결과 |
|---|---|---|
| 첫 빌드 | 1 | 공식 소스 다운로드·configure 후 C 컴파일 진행을 확인하고, 이번 실행 전용 프로세스 그룹의 병렬 make 한 개에만 SIGTERM을 전달했다. 종료 후 .local 직속 항목 집합이 시작 전과 같았다. 빌드 디렉터리·내부 staging·새 잠금·최종 prefix가 남지 않았다. |
| 같은 명령 재시도 | 0 SUCCESS | 새로 다운로드·빌드·설치했다. .local에 추가된 항목은 승인된 prefix 하나였다. 그 안의 bin/python3.12를 직접 실행해 sys.prefix와 정확한 버전 3.12.10을 확인하고 표준 라이브러리 json으로 값을 파싱했다. |
| 같은 명령 재실행 | 0 SKIPPED | 설치 트리 전체 파일 내용·권한·소유권·링크가 재실행 직전과 일치했다. 최종 Source 및 uv check도 각각 0 SKIPPED였다. |

다운로드 전 실제 uv 관리 인터프리터 경로·실행 버전과 사용자 파일을 비교 기준으로 확보했다. 중단·재설치·재실행 직후마다 uv 관리 Python 3.12.16을 직접 실행했고, 관리 설치 트리·.local/bin·SSH·Git·zsh·관리 셸 설정·프로젝트 config와 .git/config의 경로, 일반 파일 내용(SHA-256), 모드, 소유자·그룹, 링크 대상이 기준과 일치했다. 비교값과 파일 원문은 기록하지 않았다. 중단 지점은 최종 prefix 게시 전의 컴파일 단계였다.

### T21 gh 실제 검증 — 로그인 대기

기준 `2912795`, Intel macOS 15.7.5. personal SSH check와 원격 doctor는 0이었다. gh 미설치 시 check는 1 BLOCKED(훅 3)였다. 승인 후 공식 Intel macOS 배포 zip의 SHA-256을 배포 체크섬과 대조하고 gh 2.106.0을 사용자 .local/bin에 설치했다. sudo는 사용하지 않았다.

기존 Git 설정을 include하는 별도 전역 설정 파일과 전용 GH_CONFIG_DIR에서 토큰 환경 변수 없이 실행했다. 대화형 gh check는 1 CHANGE_NEEDED, 로그인 전 doctor는 4, 비대화형 apply는 1 NEEDS_ACTION(훅 4)이었다. SSH 파일·기존 Git 설정과 유효 helper·셸 설정·프로젝트 설정은 설치 전과 비교해 동일했다. 다음은 사용자 터미널에서 personal 계정으로 대화형 apply, doctor, check·재apply 검증이다. HTTPS 복원과 이후 기존 SSH 경로 대조, 교육장 OS 재검증과 초기화 후 복원은 대기다.

### T21 gh 대화형 apply 이후 대조

기준 `0d0a485`. 사용자는 일반 터미널에서 personal gh apply 종료 0을 보고했다. 검증 세션에서는 이전 실행기와 동일한 GH_CONFIG_DIR·GIT_CONFIG_GLOBAL을 재사용하고 토큰 환경 변수를 제외했다. 격리 경로에 hosts.yml·config.yml이 없었고 격리 Git 파일에서 github.com helper 조회는 1이었다. gh API는 로그인을 요구했고 doctor는 4, check와 비대화형 재apply는 각각 1 NEEDS_ACTION(훅 4)이었다. 사용자 터미널과 결과가 다른 이유는 미확정이다.

승인된 저장소의 익명 GitHub API 조회는 HTTP 404였다. 같은 저장소를 Documents 아래 별도 임시 Workspace에서 기존 personal SSH로 복원해 apply 0 SUCCESS, 재apply 0 SKIPPED, 기대한 SSH origin 일치를 확인했다. SSH 원격 doctor는 0이었고 복원 후에도 기존 사용자 파일·유효 helper가 로그인 전 비교 기준과 일치했다. 키체인 내용은 조회하지 않았다. gh 인증이 보이는 세션에서 doctor·helper·인증된 HTTPS 복원·재실행 검증을 이어간다.
