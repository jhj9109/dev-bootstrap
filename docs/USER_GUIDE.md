# Dev Bootstrap 사용자 설명서

## 1. 무엇을 하는 도구인가?

Dev Bootstrap은 매주 초기화되는 공용 iMac에서 개인 macOS 홈 디렉터리(`/Users/개인계정`)의 개발 환경을 다시 구성하는 Bash 도구입니다. 관리자 권한 없이 Git 작성자, GitHub SSH 인증, Node.js, Python, zsh 설정, iTerm2, Workspace, 프로젝트 복제를 관리합니다.

**중요:** 홈 디렉터리가 삭제되면 이전 SSH 개인키도 사라집니다. 매번 새 키를 생성하면 GitHub 계정에 새 공개키를 등록해야 합니다. 공개키 등록은 자동화하지 않았습니다.

## 2. 준비물

- macOS 사용자 계정 및 홈 디렉터리
- 기본 설치된 Git, curl, Xcode Command Line Tools
- 인터넷 연결, GitHub 계정
- SSH 공개키를 GitHub에 등록할 수 있는 브라우저
- Bash 실행 환경 (`./setup.sh`는 Bash 스크립트)

기본 셸은 zsh를 가정하지만 실행기는 Bash입니다. 관리자 권한을 요청하는 명령을 기본으로 사용하지 않습니다. 실제 설치 가능 여부는 시스템 정책과 네트워크에 따라 달라집니다.

## 3. 처음 실행하기

### 3.1 소스 준비

이 ZIP 파일을 내려받아 압축을 풀거나, 직접 게시한 GitHub 저장소를 **HTTPS**로 복제하세요. SSH 키가 없는 초기 환경이므로 처음에는 HTTPS가 편리합니다.

```bash
cd dev-bootstrap
chmod +x setup.sh bootstrap.sh  # 필요할 때만
./setup.sh doctor
```

`doctor`는 상태만 검사하며 설치나 파일 변경을 수행하지 않습니다. Linux 테스트 환경에서는 macOS 검사가 실패하는 것이 정상입니다.

### 3.2 개인 계정 설정

```bash
cp -n config/accounts.conf.example config/accounts.conf
```

사용할 필드의 주석을 풀고 값을 입력하세요. 기존 `profiles.conf`는 그대로 사용할 수 있습니다. 두 파일이 있으면 `accounts.conf`에 지정한 계정 필드가 우선합니다. 빈 문자열은 값을 지우며, 행을 삭제하면 다음 로딩에서 현재 하위 설정값을 사용합니다.

```bash
GITHUB_PERSONAL_USER="my-github-id"
GITHUB_PERSONAL_EMAIL="my-email@example.com"
GITHUB_SECONDARY_USER="other-github-id"
GITHUB_SECONDARY_EMAIL="other-email@example.com"
```

두 계정이 모두 필요한 것은 아닙니다. 사용하지 않는 프로필은 비워두어도 되지만, 해당 프로필을 선택해 실행하면 오류가 발생합니다. GitHub 사용자명은 SSH 인증에 사용하고, 이메일은 Git 커밋 작성자 설정에 사용합니다. 비밀번호나 토큰을 넣지 마세요.

### 3.3 대화형 메뉴

```bash
./setup.sh
```

인자 없이 실행하면 메뉴가 표시됩니다. 개별 작업을 수행하거나 전체 실행을 선택할 수 있습니다. 대화형 입력이 불가능한 환경에서는 명령어를 직접 사용하세요.

## 4. 권장: 매주 초기화 이후 복구 순서

```bash
# 1. HTTPS로 도구 확보 및 개인 프로필 설정
./setup.sh doctor

# 2. Git 작성자 및 SSH 키 구성
./setup.sh configure git --profile personal
./setup.sh configure github --profile personal

# 3. 안내된 .pub 파일의 내용을 GitHub 웹사이트에 등록
# GitHub → Settings → SSH and GPG keys → New SSH key

# 4. 인증 확인
./setup.sh doctor github --profile personal

# 5. 개발 도구 및 셸 환경 구성
./setup.sh install node
./setup.sh install python
./setup.sh configure shell
./setup.sh install iterm

# 6. Workspace 및 프로젝트 복원
./setup.sh configure workspace
./setup.sh repo clone OWNER/REPO
```

위 과정을 한 번에 진행하려면 `./setup.sh all`을 사용할 수 있습니다. 이 명령은 사용자 프로필을 미리 설정해야 하며, GitHub SSH 공개키 등록을 기다리거나 자동으로 완료하지 않습니다. 일부 작업이 실패하면 다른 작업을 계속한 뒤 실패 개수를 출력하고 실패 종료 상태를 반환합니다.

## 5. SSH와 GitHub CLI 중 선택

### SSH (기본)

```bash
./setup.sh configure github --profile personal
./setup.sh configure github --profile secondary
./setup.sh doctor github --profile personal
```

프로필별로 `github-personal`, `github-secondary` SSH Host를 만듭니다. 키는 각각 `~/.ssh/dev-bootstrap-personal`, `~/.ssh/dev-bootstrap-secondary`에 저장됩니다. 기존 `~/.ssh/config`의 다른 내용은 보존하고 관리용 Include를 추가합니다.

`configure github`와 메뉴 3번은 로컬 키 쌍의 지문, 관리 파일, 실제 SSH 별칭의 HostName·User·IdentityFile·IdentitiesOnly를 검사합니다. 로컬 설정이 정상이면 `SKIPPED`로 종료하고 공개키 등록 경로와 인증 확인 명령을 표시합니다. 개인키만 남아 있으면 공개키를 임시 파일로 복구해 지문을 확인합니다. 암호가 필요한 복구는 대화형 터미널에서 실행하세요.

다른 Include가 관리 파일을 중복해서 읽을 수 있거나, 같은 별칭이 이미 정의돼 있거나, Match exec·관리 파일 편집을 발견하면 자동 적용을 중단합니다. 기존 설정을 검토한 뒤 재실행하세요. 강제 종료 후 `~/.ssh/.dev-bootstrap.lock`이 남았다면 실행 중인 설정 작업과 보관된 원본을 먼저 확인하세요.

`doctor github --method ssh`와 메뉴 4번은 별도 인증 검사입니다. 별칭과 로컬 키를 확인한 뒤 해당 키로 github.com에 접속해 GitHub가 반환한 계정을 비교합니다. 신뢰가 확인된 GitHub 호스트 키가 필요합니다. doctor는 호스트 키를 추가하거나 갱신하지 않습니다.

원격 URL 예시: `git@github-personal:OWNER/REPO.git`.

기본적으로 키 암호(passphrase)를 대화형으로 입력합니다. `--no-passphrase`는 의도적으로 암호화하지 않은 키를 만들기 때문에 권장하지 않습니다. 주기적으로 GitHub 계정에서 오래된 공개키를 정리하세요.

### GitHub CLI (대체)

```bash
./setup.sh configure github --method gh --profile personal
./setup.sh doctor github --method gh --profile personal
./setup.sh repo clone OWNER/REPO --method gh
```

`gh`가 이미 설치되어 있어야 합니다. 이 프로젝트는 `gh` 자체를 설치하지 않습니다. 로그인은 브라우저 등의 사용자 개입이 필요할 수 있습니다. 두 GitHub 계정의 HTTPS 인증을 자동으로 저장소별 매핑하지 않으므로 `gh auth switch -h github.com -u 사용자명`으로 활성 계정을 확인하세요.

활성 계정이 프로필과 일치하면 github.com의 Git credential helper를 확인합니다. 계정이 다르거나 기존 호스트별 helper와 충돌하면 `NEEDS_ACTION`으로 종료합니다. 미로그인이 확인된 경우에만 대화형 로그인을 시작합니다. `doctor github --method gh`는 활성 계정을 조회하고 로그인과 helper 설정은 수행하지 않습니다.

## 6. 개발 도구 설치

```bash
./setup.sh install node                       # 기본: Node 24
./setup.sh install node --version 22
./setup.sh install python                     # 기본: uv / Python 3.12
./setup.sh install python --version 3.12.7
./setup.sh install python --version 3.12.7 --method source
./setup.sh install iterm
./setup.sh configure shell
```

- Node.js: `~/.nvm`에 nvm을 설치하고 기본 Node 버전을 지정합니다.
- **Python (uv)**은 `3`, `3.12`, `3.12.7`처럼 요청할 수 있습니다. uv가 관리하는 설치 중 요청과 일치하는 릴리스가 있고 Shell 로더도 정상이면 `SKIPPED`입니다. 시스템 Python, 활성 가상환경, 직접 빌드한 Python은 이 판정에서 제외됩니다. 로더만 빠졌으면 Shell만 복구합니다. 조회에는 `uv python find --managed-python --system --show-version`을 오프라인으로 사용합니다. uv가 명시적으로 해당 버전의 미설치를 보고할 때 설치를 시작합니다. 조회 옵션 미지원이나 예상 밖의 응답은 진단 실패로 종료합니다.
- **Python (Source)**는 전체 `X.Y.Z` 버전이 필요합니다. 설치 대상은 `~/.local/python-X.Y.Z`입니다. 인터프리터를 직접 실행해 표준 라이브러리 로드, 설치 경로와 실제 버전을 검사합니다. 기존 경로에서 검사가 실패하거나 심볼릭 링크가 발견되면 내용을 보존하고 중단합니다. 최초 빌드는 임시 경로에서 설치·검증을 마친 뒤 배치하므로 중간 빌드 실패 후 같은 명령으로 재시도할 수 있습니다. Shell과 PATH는 별도로 관리하며, 설치된 실행 파일을 직접 호출하거나 가상환경을 구성하세요.
- Shell: 기존 `.zshrc`를 보존하고 `~/.config/dev-bootstrap/env.zsh`를 연결합니다. 관리 파일과 로더가 이미 일치하면 SKIPPED로 종료합니다. 파일 끝에 marker만 남으면 로더를 복구합니다. 편집된 env.zsh나 중복 로더로 NEEDS_ACTION이 표시되면 해당 파일을 검토하세요. v1 원본은 v2 로더로 이관합니다. `configure shell`과 `all`은 선택한 환경의 Node·uv 조각만 순서대로 활성화합니다. 개별 설치는 다른 활성 조각을 보존하고, Python Source 설치는 PATH를 수정하지 않습니다. 실행 중단 후에는 같은 명령을 다시 실행하세요. 강제 종료 후 `.shell-update` 잠금이 남아 있으면 설정 작업이 끝난 것을 확인한 뒤 `rmdir "$HOME/.config/dev-bootstrap/.shell-update"`로 빈 잠금을 해제하세요. 변경 후 새 터미널을 열거나 `. ~/.zshrc`를 실행하세요.
- iTerm2: 기본적으로 `~/Applications`에 설치합니다. 기존 시스템 iTerm2가 있으면 건너뜁니다.

**주의:** nvm/uv/iTerm2 설치 과정은 외부 배포 파일을 다운로드하여 실행하거나 설치합니다. 현 버전은 배포 아티팩트 체크섬·서명을 별도로 검증하지 않습니다. 교육기관의 보안 정책에 따라 사용 여부를 결정하세요.

## 7. 저장소 관리

### 복제

```bash
./setup.sh repo clone OWNER/REPO
./setup.sh repo clone OWNER/REPO --profile secondary
./setup.sh repo clone OWNER/REPO --method gh
./setup.sh repo clone OWNER/REPO --dest "$HOME/Documents/custom-project"
```

기본 복제 경로는 `~/Documents/REPO`입니다. 이미 저장소가 있고 설정된 origin URL이 같으면 아무것도 덮어쓰지 않습니다. 다른 URL이거나 일반 디렉터리면 오류로 중단합니다. `--dest`에는 절대 경로를 사용하고 상위 디렉터리는 미리 생성하세요.

### Remote 추가

```bash
./setup.sh repo remote OWNER/REPO --repo "$HOME/Documents/my-project"
./setup.sh repo remote OWNER/REPO --repo "$HOME/Documents/my-project" --name upstream
```

일반 저장소 또는 연결된 Git worktree의 루트를 지정하세요. 연결된 worktree에서는 remote 설정이 같은 저장소의 다른 worktree와 공유됩니다. Git 디렉터리를 별도로 둔 경우 worktree를 가리키는 역참조나 명시적인 `core.worktree`가 있어야 합니다. 지정한 Remote가 없으면 추가합니다. 이미 존재하며 URL이 다르면 덮어쓰지 않습니다. 의도적으로 변경하려면 Git 명령 `git remote set-url`을 별도로 사용하고 변경 전 주소를 확인하세요.

### 여러 프로젝트 일괄 복원

```bash
cp config/repositories.conf.example config/repositories.conf
```

예시 파일:

```text
my-account/blog
my-account/backend
other-account/frontend
```

활성 목록에 `repository`가 있으면 `./setup.sh all`이 이 목록을 복원합니다. 각 행은 `OWNER/REPO` 형식이어야 하며 모두 같은 기본 인증 프로필을 사용합니다. 계정별로 다른 프로필이 필요하면 `repo clone --profile ...` 명령을 개별적으로 실행하세요. 복원이 활성화된 경우 `all`과 메뉴 10번은 첫 작업 전에 목록 전체의 형식과 목적지 이름을 검사합니다. 같은 행을 반복하거나 저장소 이름이 대소문자만 달라도 거부합니다. 서로 다른 소유자의 동명 저장소는 개별 `repo clone --dest`로 경로를 지정하세요.

목록 복원은 첫 복제 전에 모든 목적지를 확인합니다. 같은 origin의 저장소는 작업 파일과 설정을 보존하고 건너뜁니다. 새 저장소는 같은 파일시스템의 임시 디렉터리에서 복제와 origin 확인을 마친 뒤 배치합니다. 개별 복제가 실패해도 목록의 나머지 항목은 계속 시도합니다. 다시 실행하면 완료된 저장소를 건너뜁니다. 목적지나 상위 경로에 심볼릭 링크가 있으면 실제 경로를 지정하세요.

## 8. 전체 실행 설정

`--environment`는 실행 환경을, `--profile`은 사용할 GitHub 계정을 선택합니다.

```bash
./setup.sh all --environment classroom --profile personal
./setup.sh all --environment minimal --profile personal
./setup.sh --environment minimal
```

마지막 명령은 메뉴를 엽니다. 메뉴 10번과 `all`은 활성 모듈을 배열 순서대로 실행합니다. 개별 설치·설정 명령과 메뉴 번호는 계속 직접 선택할 수 있습니다.

실행 전 같은 옵션으로 계획을 확인할 수 있습니다.

```bash
./setup.sh plan --environment minimal --profile secondary
./setup.sh all --dry-run --environment minimal --profile secondary
```

두 명령은 환경, 계정, 인증 방식, 대상 OS와 모듈별 실행 순서·선행 조건을 표시합니다. 설치나 인증 상태를 조회하지 않으며 유효한 계획은 코드 0으로 종료합니다. 선행 모듈을 빠뜨리거나 뒤에 놓으면 코드 2로 종료하므로 출력된 모듈명을 보고 배열을 수정하세요. Node와 uv Python 앞에는 `shell`, 일괄 저장소 복원 앞에는 `workspace`를 두세요. 소스 방식 Python은 단독으로 선택할 수 있습니다. `shell`을 생략하면 기존 셸 활성 목록이 유지됩니다.

### 상태 검사와 적용

```bash
./setup.sh check --environment minimal
./setup.sh apply workspace
./setup.sh check git --profile secondary --repo "$HOME/Documents/project"
./setup.sh apply python --method source --version 3.12.7
```

`check`는 각 목표를 읽기 전용으로 검사합니다. `SKIPPED`는 이미 충족, `CHANGE_NEEDED`는 변경 필요, `FAILED`는 진단 또는 실행 실패입니다. `apply`와 `all`은 환경 목록 순서대로 필요한 변경을 적용하고 검증합니다. 모듈 ID를 붙인 `check`와 `apply`는 등록된 해당 대상과 선행 모듈만 다룹니다. 단일 `apply`는 대상만 변경하므로, 선행이 미충족이면 요약에 표시된 선행 모듈부터 적용한 뒤 재시도하세요. Shell 적용은 선택한 환경의 활성 조각을 따릅니다. 단일 Node·uv의 셸 조각도 준비하려면 해당 런타임을 환경에 포함하세요.

공통 옵션은 `--profile`, 인증 방식 `--method ssh|gh`, SSH용 `--no-passphrase`입니다. 단일 Git에는 `--global` 또는 `--repo PATH`, 단일 Node·Python에는 `--version`, 단일 Python에는 설치 방식 `--method uv|source`를 지정할 수 있습니다. `--dry-run`은 `all`에서 사용합니다.

요약은 ID별 결과·단계·사유와 재실행 명령을 보여줍니다. 선행이 실패한 항목은 `BLOCKED`로 표시하고 독립 항목은 계속 실행합니다. 모든 목표가 충족되면 0, 변경 필요 또는 실행 미완료면 1, 옵션·설정·계획이 잘못되면 2로 종료합니다. 복원 목록 형식 오류도 첫 훅 전에 2로 종료합니다. 빈 환경 목록의 전체 검사는 0입니다.

`config/defaults.conf`에서 공통 기본값을 지정합니다.

```bash
DEFAULT_ENVIRONMENT=classroom
WORKSPACE_DIR="$HOME/Documents"
DEFAULT_AUTH_METHOD=ssh
DEFAULT_GITHUB_PROFILE=personal
NODE_VERSION=24
PYTHON_VERSION=3.12
INSTALL_ITERM=true
INSTALL_NODE=true
INSTALL_PYTHON=true
PYTHON_INSTALL_METHOD=uv
```

모듈 기본값 위에 공통 defaults, `config/environments/<환경>.conf`, 개인 `config/profiles.conf`, 계정 전용 `config/accounts.conf`를 차례로 적용합니다. 명령행에서 지정한 계정·방식·버전은 해당 실행에 우선합니다. 환경 파일은 명령행의 `--environment`, 생략하면 공통 defaults의 `DEFAULT_ENVIRONMENT`로 고릅니다. 메뉴는 매 선택 시 설정을 다시 읽습니다.

`minimal`의 기본 목록은 `ENABLED_MODULES=(workspace git github shell)`입니다. 환경 파일이나 개인 설정에서 이 형식으로 목록을 바꿀 수 있습니다. 등록된 모듈 ID를 각각 한 번씩 적으세요. 명시한 빈 배열 `ENABLED_MODULES=()`은 전체 실행에서 모든 단계를 건너뜁니다. `classroom`에 목록을 지정하지 않으면 Workspace·Git·GitHub·Shell과 저장소 복원을 포함하고, 기존 `INSTALL_NODE`, `INSTALL_PYTHON`, `INSTALL_ITERM` 중 값이 `true`인 설치 단계를 포함합니다. 명시한 배열이 있으면 그 목록이 우선합니다.

설정 파일은 신뢰할 수 있는 Bash 코드만 사용하세요. 설정 오류는 코드 2로 종료하며, 메뉴 재로딩 중에는 해당 선택을 취소하고 마지막 정상 설정을 보존합니다.

## 9. 테스트 및 확인

```bash
./scripts/verify.sh
./setup.sh doctor
```

자동 테스트는 실제 홈 디렉터리 대신 임시 홈 디렉터리를 사용합니다. 네트워크 설치, 실제 SSH 인증, macOS 전용 설치의 성공을 보장하지 않습니다.

## 10. 문제 해결

| 현상 | 확인 및 해결 |
| --- | --- |
| `Set GITHUB_...` 오류 | `config/accounts.conf` 또는 기존 `config/profiles.conf`에서 선택한 계정의 사용자명과 이메일 확인 |
| SSH 인증 실패 | 공개키 GitHub 등록 여부, Host 별칭, 네트워크 확인 후 `doctor github` |
| `gh not installed` | `gh`를 별도 설치하거나 기본 SSH 방식 사용 |
| 기존 저장소 URL 충돌 | `git -C 경로 remote -v`로 확인, 자동 덮어쓰기 없음 |
| Python 설치했지만 `python3` 버전이 다름 | uv 관리 Python과 시스템 Python은 별개. `uv python find 3.12 --managed-python --system`, `uv venv` 활용 |
| Node 명령이 새 터미널에 없음 | `./setup.sh configure shell` 실행 후 새 zsh 시작 |
| `all`이 일부 실패 | 로그에서 실패 모듈 확인 후 개별 명령으로 재시도 |
| SSH 공개키가 매주 늘어남 | GitHub Settings에서 더 이상 사용하지 않는 키를 확인해 삭제 |

## 11. 권장 운영 수칙

공용 iMac에서는 개인키를 Git 저장소나 공유 폴더에 보관하지 마세요. 매주 초기화 전에 필요한 작업은 GitHub에 push하고, 다른 곳에 보관해야 할 데이터는 기관 정책에 맞게 백업하세요. 이 도구는 파일 백업 도구가 아니며 초기화로 삭제된 로컬 파일을 복구하지 않습니다.
