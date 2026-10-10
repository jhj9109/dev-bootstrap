# Dev Bootstrap 코드 리뷰 가이드

> 기준: Phase 4 소스코드. 이 문서는 실제 파일과 함수 이름을 따라 읽는 안내서다. 기존 코드를 수정하지 않는다.

## 0. 리뷰 목표와 증거 수준

- **설명 가능**: 요구사항과 호출 경로를 스스로 설명할 수 있다.
- **정적 확인**: 인자 검사, 파일 쓰기, 오류 처리, 외부 명령을 코드에서 식별했다.
- **자동 검증**: 로컬/모의 테스트에서 예상 결과를 확인했다.
- **실기기 검증**: 실제 macOS 계정과 네트워크에서 동작을 확인했다.

앞 단계의 증거가 뒤 단계의 증거를 대체하지 않는다. 특히 모의 `ssh-keygen`, `ssh`, `nvm`, `uv` 테스트는 실제 바이너리와 네트워크 동작을 입증하지 않는다.

## 1. 먼저 전체 그림을 읽기

사용자 → `setup.sh` → `lib/*.sh` 및 `modules/*.sh` source → `main "$@"` → 명령 파싱 → 모듈 함수 → 종료 코드.

`source`는 별도 프로세스를 실행하지 않고 현재 Bash 프로세스에 함수와 변수를 가져온다. `setup.sh`는 `set -o pipefail`을 사용하지만 `set -e`나 `set -u`는 사용하지 않는다. 따라서 **모든 오류가 자동 중단된다고 가정하지 말고**, 각 함수의 `|| return`과 조건문을 읽어야 한다.

### 실제 함수 호출 지도

| CLI | `setup.sh` 진입 함수 | 이어지는 함수 | 주요 부작용 |
|---|---|---|---|
| `doctor` | `main` → `doctor` | `lib/platform.sh` | 사용자 홈에 쓰기 없음 |
| `configure git` | `main` → `configure_git` | `profile_load` | Git config 변경 |
| `configure github` (기본 SSH) | `main` → `configure_github` | `ssh_setup` → `profile_load` | SSH 키/설정 생성 또는 보존 |
| `configure github --method gh` | `main` → `configure_github` | `gh_setup` | gh 로그인 및 Git 인증 설정 |
| `install node` | `main` → `run_install` | `node_check`, `node_install`, `shell_configure` | nvm, Node, `.zshrc` |
| `install python` | `main` → `run_install` | `python_check`, `python_install`, `shell_configure`(uv) | Python, uv, `.zshrc` |
| `install iterm` | `main` → `run_install` | `iterm_check`, `iterm_install` | `~/Applications` |
| `configure workspace` | `main` → `workspace_configure` | — | Workspace 디렉터리 |
| `repo clone` | `main` → `repo_clone` | `profile_load`, `repo_url`, `workspace_configure` | 저장소 복제 |
| `repo remote` | `main` → `repo_remote` | `profile_load`, `repo_url` | Git remote 추가 |
| `all` | `main` → `run_all` | 위 기능을 순차 실행 | 여러 설정과 설치 |

## 2. 권장 독서 경로 (1~7회차)

### 1회차: `setup.sh` — 제어 흐름

1. **1~11행**: 스크립트 루트 경로 계산, 공통 라이브러리와 모듈을 `source`하는 순서.
2. **12~36행**: `usage`에 공개된 CLI 계약.
3. **37~70행**: `parse_options` / `parse_install_options`에서 기본값, 옵션, 입력 검증.
4. **71~95행**: `run_install`에서 설치 여부에 따라 실행 경로 분기.
5. **96~118행**: `run_all`에서 실행 순서, 실패 누적, 저장소 목록 처리.
6. **119~140행**: 인자 없는 대화형 메뉴.
7. **141행 이후**: `main`의 명령 분기 및 종료 코드.

질문: `configure github --method ssh --profile secondary`가 어떤 함수와 설정값을 거치는가? `all`에서 GitHub 단계가 실패해도 Node 단계가 실행되는 이유는 무엇인가? `doctor`와 `configure`의 상태 변경 차이는 무엇인가?

### 2회차: `lib/config.sh`, `lib/profiles.sh`

- `load_config`: `defaults.conf`를 먼저 읽고 선택적으로 `profiles.conf`를 읽는다. 후자가 앞의 값을 덮어쓸 수 있다.
- `profile_load`: `personal` 또는 `secondary`를 검사하고 `PROFILE_USER`, `PROFILE_EMAIL`, `PROFILE_ALIAS`, `PROFILE_KEY`를 만든다.
- 주의: `.conf` 파일은 `source`로 실행되므로 **신뢰하지 않는 파일을 복사해 넣으면 안 된다**. 계정별 비밀키와 토큰은 여기에 기록하지 않는다.
- 질문: `--profile secondary`는 실제 GitHub 사용자 이름과 어떤 관계인가? `PROFILE_KEY`는 어디에 만들어지는가?

### 3회차: `modules/git.sh`

- `configure_git(profile, scope, repo)`는 프로필 로드 → Git 존재 확인 → `--global`/`--local` 분기 → `user.name`, `user.email` 설정 → 값 확인 순서다.
- 전역 Git 설정과 SSH 인증은 별개다. `user.name`은 GitHub 로그인 여부를 보장하지 않는다.
- 주의: `user.name` 설정이 성공하고 `user.email` 설정이 실패하면 일부 설정만 바뀔 수 있다. 트랜잭션/롤백은 구현되어 있지 않다.
- 질문: 로컬 설정은 어떤 저장소에 기록되는가? 기존 Git 사용자 정보는 덮어쓰는가?

### 4회차: `modules/github.sh`, `modules/auth/ssh.sh`, `modules/auth/gh.sh`

- `github.sh`는 인증 방식에 따라 SSH 또는 gh 구현을 선택한다.
- `ssh_setup`: 경로의 심볼릭 링크 검사 → `~/.ssh` 생성 및 권한 설정 → 기존 키 유효성 검사 또는 신규 키 생성 → 공개키 보완 → SSH `Include` 추가 → 관리 파일 재생성 → SSH 설정 확인 → 공개키 출력.
- `ssh_doctor`: `ssh -T`의 메시지에 `successfully authenticated`와 기대 계정명이 포함되는지 검사한다. GitHub는 성공 인증에서도 종료 코드 1을 반환할 수 있으므로 종료 코드만으로 판정하지 않는다.
- `gh_setup`: `gh`가 **이미 설치되어 있어야** 한다. 로그인 후 `gh api user`로 활성 계정을 확인하고 `gh auth setup-git`을 호출한다. 다중 계정 전환은 완전 자동화되지 않았다.
- 질문: 기존 키를 덮어쓰지 않는다는 증거는? 공개키 출력과 GitHub 등록 완료는 어떻게 다른가? `--no-passphrase`가 왜 보안상 주의 대상인가?

### 5회차: `modules/repository.sh`, `modules/workspace.sh`

- `repo_parse_spec`는 `OWNER/REPO` 형식을 검사한다.
- `repo_url`은 SSH면 `git@github-PROFILE:OWNER/REPO.git`, gh면 HTTPS URL을 만든다.
- `repo_clone`은 목적지가 없으면 clone, 이미 있으면 `.git`과 `origin` URL 일치 여부만 확인하고 건너뛴다. **원격 최신 커밋으로 갱신하는 기능은 아니다.**
- `repo_remote`는 기존 remote의 URL이 다르면 덮어쓰지 않는다.
- 질문: 기존 폴더가 Git 저장소이지만 다른 원격 주소를 가지면? 같은 저장소 이름을 가진 서로 다른 소유자의 프로젝트는 어떻게 처리되는가?

### 6회차: `modules/node.sh`, `modules/python.sh`, `modules/shell.sh`, `modules/iterm.sh`

- Node: nvm 설치 여부 확인 → 공식 설치 스크립트 다운로드 및 실행 → `nvm install` → 기본 버전 설정 → 셸 초기화 → 검증.
- Python uv: uv 존재 확인 → 설치 스크립트 다운로드 및 실행 → `uv python install` → 셸 초기화 → 버전 검색으로 검증.
- Python source: 정확한 `X.Y.Z` 버전 필요 → 소스 압축 파일 다운로드 → 컴파일 → 사용자 홈 아래 설치.
- Shell: `~/.config/dev-bootstrap/env.zsh`를 관리하고 `.zshrc`에 연결 줄을 중복 없이 추가.
- iTerm2: macOS에서 ZIP을 받아 `ditto`로 풀고 `~/Applications`에 복사.
- **검토 과제**: nvm/uv 설치 스크립트와 iTerm2 ZIP은 현재 다운로드 무결성 고정 검증이 없다. 설치 전에 다운로드 출처와 실행 위험을 평가한다. `uv python install`은 설치된 Python을 일반적인 `python3` 명령으로 반드시 노출시키는 것은 아니다.

### 7회차: 테스트에서 계약 찾기

`TEST_REVIEW_GUIDE.md`를 함께 읽고 테스트별 Given / When / Then과 실제 assertion을 대응시킨다.

## 3. 한 함수 리뷰용 템플릿

```text
함수/파일:
목적:
호출자:
입력 및 기본값:
출력 및 종료 코드:
읽는 파일:
생성/변경하는 파일:
외부 명령/네트워크:
정상 경로:
실패 경로:
재실행 시 행동:
기존 데이터 보호:
테스트 근거:
아직 검증하지 못한 것:
내가 설명할 수 있는가? (예/아니오)
```

## 4. 코드 리뷰 시 우선 확인할 위험

| 우선순위 | 발견/관찰 | 확인해야 할 것 |
|---|---|---|
| 높음 | 외부 설치 스크립트를 내려받아 실행함 | 체크섬/서명 또는 고정 버전 검증 정책 부재. 공급망 위험과 네트워크 실패를 검토 |
| 높음 | `profiles.conf`를 Bash `source`로 실행함 | 파일 신뢰 경계, 설정 파일 변경 이력 및 검토 |
| 높음 | SSH 키를 사용자 홈에 생성함 | 권한, 암호 설정, GitHub 키 폐기 정책, 실제 macOS 검증 |
| 중간 | `gh` 방식은 설치를 수행하지 않음 | `gh`가 없는 초기화 환경에서의 안내/대체 절차 |
| 중간 | `repo clone`은 기존 origin URL만 확인함 | 작업 트리 상태/최신 커밋/브랜치 검증은 별도 필요 |
| 중간 | `all`은 실패 후 독립 단계를 계속 실행함 | 부분 성공 상태를 기록하고 재시도할 방법 |
| 중간 | Git 설정은 순차적 변경임 | 중간 실패 시 부분 변경 가능성 |
| 중간 | `doctor`는 필수 도구와 경로 중심 | 실제 인증/버전/설치 성공 여부와 별도 판단 |
| 중간 | 일부 테스트는 명령을 모의함 | 실제 다운로드/인증/실기기 호환성 테스트 보완 |

## 5. 추천 리뷰 기록 방식

리뷰할 때마다 `REVIEW_RECORD.md` 양식을 복사해 한 기능씩 기록한다. **설명할 수 있는 코드**와 **테스트로 입증한 코드**를 반드시 구분한다.
