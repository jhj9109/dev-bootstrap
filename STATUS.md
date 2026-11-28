# 프로젝트 상태

2026-11-27 기준 `refactor/dev-bootstrap-v2`에서 Phase 7의 T20 안정화와 운영 문서 현행화를 완료했다. v1 회귀 검증의 기준 리비전은 `44c15d5`다.

| 항목 | 현재 상태 |
|---|---|
| 완료 | CLI와 메뉴를 분리하고 시작 시 Registry에서 등록 정보를 검증한다. Workspace 단일 명령과 메뉴 9번은 같은 Runner를 통해 등록된 훅을 실행한다. |
| 하네스 개선 | Task ID로 시작하는 작업·커밋·푸시 절차를 [AGENTS.md](AGENTS.md)에 통합했다. Linux Bash에서 저장소 밖에서 실행한 [전체 검증](scripts/verify.sh)은 셸 파일 30개 문법 검사와 회귀 테스트 8개를 통과했다. 임시 Git fixture에서 테스트 0개, 추적 파일 누락, 문법 오류, 새 하위 테스트 실패(종료 코드 23)의 비정상 종료를 확인했다. |
| T02 검증 | Linux Bash에서 신규 모듈 포함 문법 검사 및 기존 7개와 Registry 테스트 1개 통과. 두 진입점에서 잘못된 모듈이 사용자 파일 변경 전에 거부되는지 확인했다. [테스트 지침](docs/TESTING.md) |
| T03 검증 | Linux에서 셸 파일 33개 문법 검사와 테스트 10개 통과. Runner의 상태·훅 코드·호출 순서·셸 격리, Workspace 최초 적용·재실행, 파일·링크 보존과 CLI 종료 코드 1·2·5를 확인했다. [테스트 지침](docs/TESTING.md) |
| T04 검증 | Linux에서 셸 파일 34개 문법 검사와 테스트 10개 통과. 모의 Darwin에서 iTerm2 최초 설치·재실행·부분 복사 실패 후 재설치, CLI·메뉴·all 경로, 미지원 플랫폼 및 종료 코드 1·3·5를 확인했다. |
| T05 검증 | Linux에서 셸 파일 36개 문법 검사와 테스트 11개 통과. 실제 Git 저장소와 연결된 worktree에서 범위별 적용·재실행, 반대 범위와 다른 키 보존, 조회·쓰기·사후 검증 실패 및 CLI 코드 1·2·3·5를 확인했다. |
| T06 검증 | Linux에서 셸 파일 38개 문법 검사와 테스트 12개 통과. 단일 env.zsh 및 .zshrc 로더 판정, 파일 쓰기 없는 재실행, 편집·권한·링크 보존, 실패 후 복구와 Node·Python 호출 경로를 확인했다. |
| T07 검증 | Linux에서 셸 파일 40개 문법 검사와 테스트 13개 통과. nvm 최초 설치, 버전·alias 해석, Shell만 복구, 조회 실패 시 변경 0회, 훅 격리와 CLI·메뉴·all 경로를 확인했다. |
| T08 검증 | Linux에서 셸 파일 42개 문법 검사와 테스트 14개 통과. uv 관리 버전과 Shell 상태, Source 인터프리터의 버전·실행 검사, 빌드 실패 후 재시도, 기존 파일·링크 보존 및 CLI 종료 코드 1·2·3·5를 확인했다. |
| T09 검증 | Linux에서 셸 파일 44개 문법 검사와 테스트 15개 통과. SSH 로컬 완료와 원격 인증 분리, 기존 키·설정 보존과 복구, gh 계정·helper 판정, CLI·메뉴·all 경로를 모의 도구로 확인했다. |
| T10 검증 | Linux x86_64, Bash 5.2.37, Git 2.56.1에서 셸 파일 46개 문법 검사와 테스트 16개 통과. 실제 로컬 Git으로 두 저장소의 목록 복원, 같은 origin의 SKIPPED, 다른 origin과 사용자 파일 보존, 연결된 worktree, 부분 실패 후 재시도 및 CLI·메뉴 10번·all을 확인했다. |
| Phase 2 완료 | T04~T10의 기존 회귀와 모듈별 오류·재실행 검사를 통과했다. 모의 다운로드·설치·인증 도구로 확인한 항목과 Intel iMac에서 확인할 항목을 [테스트 지침](docs/TESTING.md)에 기록했다. |
| T11 검증 | Linux x86_64의 Bash 5.2.37과 Linux용으로 빌드한 Bash 3.2.57에서 각각 셸 파일 47개 문법 검사와 테스트 17개를 통과했다. 임시 모듈의 설정 등록·우선순위, 키 충돌, 훅 격리, 잘못된 후보와 손상된 스냅샷 거부 후 전체 설정 보존을 확인했다. |
| T12 검증 · Bash 5.2.37 | Linux x86_64에서 셸 파일 48개 문법 검사와 테스트 18개 통과. 환경과 계정의 독립 선택, 명시 배열과 레거시 변환, 비활성 복원 생략, 비정상 배열과 손상된 스냅샷의 원자적 거부를 확인했다. |
| T12 검증 · Bash 3.2.57 | 같은 Linux 호스트에서 Apple 공개 소스로 빌드한 Bash로 전체 검증을 다시 실행해 문법 검사 48개와 테스트 18개 통과. 빈 배열과 미설정의 구분, 메뉴 재로딩 및 기존 all 경로를 포함한다. |
| T13 및 Phase 3 검증 | Linux Bash 5.2.37 및 Linux용 Bash 3.2.57에서 각각 셸 파일 49개 문법 검사와 테스트 19개 통과. 환경 선택·레거시 all, 계정 필드별 우선순위·삭제·빈 값, 메뉴의 Git 설정 갱신, GitHub SSH·gh 및 실패 후 전체 설정 보존을 확인했다. |
| Phase 4 전 하네스 개선 | 중간 체크포인트와 Git 대조 재개 절차를 추가했다. Linux Bash 5.2.37 및 3.2.57에서 각각 셸 파일 51개 문법 검사와 테스트 20개를 통과했다. 매트릭스의 중첩 Bash·env 진입점 선택, 테스트 실패 및 실행 불가·버전 불일치 처리를 확인했다. [테스트 지침](docs/TESTING.md) |
| T14 검증 | Linux Bash 5.2.37·3.2.57에서 각각 셸 파일 53개 문법 검사와 테스트 21개 통과. 실제 Linux zsh 5.9에서 임시 HOME의 v1 유지·전환 실패 후 재시도, 사용자 .zshrc와 권한 보존, 활성 순서·잘못된 목록 거부·반복 로드 시 PATH를 확인했다. |
| T15 및 Phase 4 검증 | Linux Bash 5.2.37·3.2.57 각각 셸 파일 54개 문법 검사와 테스트 22개 통과. CLI·메뉴·all 재실행, classroom→minimal, 개별 설치 병합, 편집 파일·링크 보존, v1 이관 및 v2 목록·조각 교체 실패 후 재시도를 확인했다. |
| 실제 zsh | Linux zsh 5.9에서 두 번 source한 후 uv·Node fixture 명령과 PATH를 확인했다. 별도 임시 HOME에서도 공식 nvm 0.40.3의 함수, 모의 기본 Node v24.8.0 선택 및 NVM_BIN 경로 단일 등록을 확인했다. |
| T16 검증 | Linux x86_64에서 Bash 5.2.37과 Apple 공개 소스로 빌드한 Bash 3.2.57이 각각 문법 검사 56개와 테스트 23개를 통과했다. 실제 zsh 5.9 회귀를 포함한다. 두 계획 진입점에서 복수 의존성과 오류 코드 2, 호출 기록 0회, 임시 HOME 보존, 기존 로더가 있는 빈 계획의 정상 종료를 확인했다. 잘못된 일괄 계획에서도 개별 Workspace 명령은 정상 실행됐다. |
| T17 검증 | Linux x86_64에서 Bash 5.2.37과 3.2.57 각각 문법 검사 57개와 테스트 24개 통과. 실제 zsh 5.9 회귀를 포함한다. 선행 실패의 전이 차단, 공유 선행의 단일 진단, 독립 모듈 진행, 읽기 전용 check와 단일 apply 차단 시 HOME 보존, 빈 계획 및 재실행을 확인했다. 실행 중 복원 목록을 교체해도 최초 스냅샷으로 복원되며 Workspace 생성은 한 번이었다. |
| T18 및 Phase 5 검증 | Linux Bash 5.2.37·3.2.57 각각 문법 검사 58개와 테스트 25개 통과. 실제 zsh 5.9 회귀 포함. 임시 모듈의 세 화면 노출·선택, 기존 메뉴와 특수 명령 인자 보존, all의 SSH 안내를 확인했다. 잘못된 계획의 첫 쓰기 전 거부, dry-run의 HOME 보존·설치 호출 0회, 선행 실패의 전파와 독립 항목 완료도 통과했다. |
| T19 및 Phase 6 검증 | 기준 `b71ba5a`, Linux x86_64 Bash 5.2.37 및 Apple 공개 소스로 빌드한 3.2.57에서 각각 문법 검사 59개와 테스트 26개 통과. 실제 Linux zsh 5.9 회귀 포함. 임시 모듈의 화면 노출·메뉴 선택, 목표 변경·검증·재실행, 설정 거부, 단계별 실패와 의존 항목 차단·독립 항목 완료를 확인했다. 추가 전후와 실행 후 두 진입점 및 core·lib의 13개 파일을 대조했고 차이는 0건이었다. 환경 이름과 버전 옵션의 확장 범위는 [테스트 지침](docs/TESTING.md)에 기록했다. |
| T20 검증 | Linux Bash 5.2.37과 3.2.57 각각 문법 검사 59개·테스트 26개 통과. T19 확장성과 실제 zsh 5.9 회귀를 포함한다. 임시 HOME에서 문서의 조회·계획·적용·재실행과 파일 보존을 확인했다. 도구별 다운로드 검증·정리 범위는 [운영 한계](docs/DESIGN_AND_LIMITATIONS.md)에 기록했다. |
| T21 교육장 부분 검증 | `18c05d7`, iMac20,1(x86_64), macOS 26.5.2(25F84), Bash 3.2.57·zsh 5.9에서 문법 59개·회귀 26개 통과. minimal·classroom plan/dry-run 일치, Git·Workspace SKIPPED, Shell CHANGE_NEEDED. GitHub SSH check가 OrbStack Include에서 NEEDS_ACTION(훅 4)으로 중단됐다. |
| T21 SSH 수정본 자동 검증 | Linux x86_64 Bash 5.2.37·3.2.57 각각 문법 60개·회귀 27개 통과. OpenSSH 10.0p2로 임시 HOME의 orb 설정 보존과 두 GitHub 프로필 격리를 확인했다. 원격 인증 응답은 모의했다. |
| T21 개인키 지문 | 교육장 iMac의 a672b21에서 OpenSSH 10.2p1은 개인키 경로 검사에 성공했으나 /dev/stdin 경유 시 255로 실패해 OrbStack 테스트의 GitHub apply가 중단됐다. 보호된 임시 디렉터리의 링크로 개인키 자체를 검사하도록 수정했다. Intel macOS 15.7.5, OpenSSH 9.9p2에서 전체 매트릭스 Bash 5.3.0·3.2.57 각각 문법 61개·회귀 28개 통과. 교육장 26.5.2 수정본은 재검증 대기다. |
| T21 수정본 재검증 | `0854da5`, iMac20,1(x86_64), macOS 15.7.5(24G624), OpenSSH 9.9p2. 기본 Bash 3.2.57에서 지문·OrbStack 단독 검사 통과 후 전체 verify.sh 문법 61개·회귀 28개 통과. 교육장 macOS 26.5.2·OpenSSH 10.2p1 재검증은 대기다. |
| T21 로컬 상태 점검 | 2026-11-28, `dd062dc`, Intel macOS 15.7.5. doctor 0(경고 2), minimal·classroom plan과 dry-run 일치. Workspace 충족, 저장소 목록 비어 있음. Git·GitHub는 personal 설정 누락, Shell·iTerm2는 변경 필요, Node·Python은 Shell 선행 조건으로 차단. 다음은 전용 계정 설정과 승인 후 적용·인증이다. [검사별 결과](docs/TESTING.md#2026-11-28-로컬-읽기-전용-점검) |
| T21 실제 적용 중간 결과 | 기준 `12549ae`. personal 설정 유효. Git·Shell 각각 실제 HOME에서 check 1 → apply 0 → check 0(SKIPPED). GitHub SSH는 사용자 터미널의 키 생성 대기. 이후 런타임·앱 적용, 새 zsh와 원격 인증 검증 대기. |
| T21 로컬 실제 적용 | 기준 `0904424`. 사용자 확인으로 personal SSH 원격 인증 성공(최초 호스트 키 미등록 255 해결), 로컬 check 0. Node·Python(uv)·iTerm2·테스트 저장소 SSH 복원 각각 적용 전 1 → apply 0 → check·재apply 0 SKIPPED. 새 zsh 런타임 실행과 iTerm2 프로세스 확인. 후속 후보는 최초 호스트 키 확인 안내와 인증 실패 원인별 진단이다. |
| T21 classroom 전체 | 기준 `628f13a`, 로컬 Intel macOS 15.7.5. 실제 HOME·별도 목록 1건으로 전체 check 1(repository만 변경 필요) → all 0(SSH 복원 성공) → check·all·check 모두 0(8개 SKIPPED). 매 단계 사용자 설정·SSH 키·모드와 작업 저장소 origin 보존, 복원 이후 복제본 전체 파일 일치 확인. Python Source·gh 인증·설치 중단 복구의 후속 조건은 TESTING에 기록했다. |
| T21 Python Source 중단 복구 | 기준 `02aadaf`, Intel macOS 15.7.5. CPython 3.12.10 컴파일 중 전용 make 중단 → apply 1, staging·잠금·부분 prefix 잔여 없음. 동일 요청 재설치 0 SUCCESS, 지정 인터프리터·표준 라이브러리 실행, 재실행 0 SKIPPED 및 prefix 보존. 각 단계 기존 uv Python 3.12.16과 사용자 파일 비교 통과. |
| T21 gh 준비 | Intel macOS 15.7.5에서 gh 2.106.0 사용자 설치 및 체크섬 확인. 기존 SSH doctor 0. 격리된 gh·Git 설정으로 로그인 전 TTY check 1, doctor 4. personal 대화형 로그인과 인증 후 helper·HTTPS 복원·SSH 재검증 대기. |
| T21 gh 로그인 후 대조 | 일반 터미널 apply 0(사용자 보고). 동일 격리 경로에서 검증 세션은 로그인 정보와 github.com helper를 확인할 수 없어 doctor 4·check/재apply 1. 기존 SSH doctor 0, 승인 저장소 SSH 복원 0·재실행 SKIPPED, 사용자 파일·helper 기준 일치. 인증된 HTTPS 복원은 대기다. |
| T21 gh 실제 인증 완료 | 기준 `1f019a5`. personal 로그인·apply·doctor 0, 독립 doctor 0, check·재apply 0 SKIPPED. 격리 Git helper로 승인된 비공개 저장소 HTTPS 복원 성공, 재실행 SKIPPED. 기존 SSH doctor 0, 사용자 파일·기존 helper 보존 확인. 교육장 검증·초기화 후 복원 대기. |
| 추가 환경 관찰 | 이 환경에서 직접 빌드한 Bash 5.2.0·5.2.37은 계정 설정 테스트에서 SIGSEGV로 중단됐다. 5.2.37은 기준 커밋에서도 동일하게 재현됐다. |
| 미검증 및 알려진 제약 | 교육장 macOS 26.5.2·OpenSSH 10.2p1의 OrbStack 공존과 현장 설치·인증, 초기화 후 복원은 재검증 대기다. 다운로드 파일별 독립적인 무결성 검증이 제한적이다. |
| 검토할 결정 | 편집된 env.zsh의 수동 이관 |
| SSH doctor 실패 진단 | T21 미등록 호스트 키(255) 등 원인별 안내와 최초 신뢰 절차 추가. Intel macOS 15.7.5 격리 복제본에서 Bash 5.3.0·3.2.57 전체 매트릭스 통과. 교육장 실기기·초기화 후 복원 대기. |
| 테스트 하네스 격리 | 기준 `e027581`. 테스트용 프로젝트에는 현재 작업 트리의 제품 코드와 공유 설정만 복사한다. Intel macOS 15.7.5의 실제 작업 트리·깨끗한 임시 작업 트리·모의 개인 설정이 있는 임시 작업 트리 모두 Bash 5.3.0·3.2.57 각각 문법 63개·회귀 29개 통과. 모의 계정·프로필·복원 목록의 검증 전후 내용 일치. [검증 방법](docs/TESTING.md#테스트-프로젝트와-개인-설정-격리) |
| 다음 작업 | Phase 7의 T21은 진행 중이다. 승인된 Intel iMac 테스트 계정에서 [실기 검사 절차](docs/TESTING.md)에 따라 실제 설치·인증·초기화 후 복원을 확인한다. [구현 작업 목록](docs/TASKS.md) |
