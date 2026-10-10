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
cp config/profiles.conf.example config/profiles.conf
```

파일을 편집하세요.

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

# 3. 출력된 공개키를 GitHub 웹사이트에 등록
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

원격 URL 예시: `git@github-personal:OWNER/REPO.git`.

기본적으로 키 암호(passphrase)를 대화형으로 입력합니다. `--no-passphrase`는 의도적으로 암호화하지 않은 키를 만들기 때문에 권장하지 않습니다. 주기적으로 GitHub 계정에서 오래된 공개키를 정리하세요.

### GitHub CLI (대체)

```bash
./setup.sh configure github --method gh --profile personal
./setup.sh doctor github --method gh --profile personal
./setup.sh repo clone OWNER/REPO --method gh
```

`gh`가 이미 설치되어 있어야 합니다. 이 프로젝트는 `gh` 자체를 설치하지 않습니다. 로그인은 브라우저 등의 사용자 개입이 필요할 수 있습니다. 두 GitHub 계정의 HTTPS 인증을 자동으로 저장소별 매핑하지 않으므로 `gh auth switch -h github.com -u 사용자명`으로 활성 계정을 확인하세요.

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
- Python: 기본 방식은 uv입니다. Python은 uv 관리 경로에 설치되며, 일반 `python3` 명령이 즉시 그 버전을 가리킨다는 뜻은 아닙니다. 프로젝트에서는 `uv run`, `uv venv` 등으로 버전을 선택하세요.
- Python 소스 빌드: 전체 `X.Y.Z` 버전이 필요하고 컴파일 시간이 길 수 있습니다. 설치된 Python 경로를 직접 사용하거나 가상환경을 구성하세요.
- Shell: 기존 `.zshrc`를 보존하고 `~/.config/dev-bootstrap/env.zsh`를 연결합니다. 변경 후 새 터미널을 열거나 `. ~/.zshrc`를 실행하세요.
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

지정한 Remote가 없으면 추가합니다. 이미 존재하며 URL이 다르면 덮어쓰지 않습니다. 의도적으로 변경하려면 Git 명령 `git remote set-url`을 별도로 사용하고 변경 전 주소를 확인하세요.

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

이 목록은 `./setup.sh all`을 실행할 때 복제합니다. 각 행은 `OWNER/REPO` 형식이어야 하며 모두 같은 기본 인증 프로필을 사용합니다. 계정별로 다른 프로필이 필요하면 `repo clone --profile ...` 명령을 개별적으로 실행하세요. 이름이 같은 두 저장소는 기본 Workspace 경로에서 충돌합니다.

## 8. 전체 실행 설정

`config/defaults.conf`의 값을 수정할 수 있습니다.

```bash
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

설정 파일은 Bash 코드로 로드되므로 출처가 불분명한 설정을 복사하지 마세요. `INSTALL_*`을 `false`로 설정하면 전체 실행에서 해당 설치 단계를 생략합니다. 개별 `install` 명령에는 영향을 주지 않습니다.

## 9. 테스트 및 확인

```bash
bash -n setup.sh lib/*.sh modules/*.sh modules/auth/*.sh tests/*.sh
bash tests/test_cli.sh
bash tests/test_phase2.sh
bash tests/test_phase3.sh
bash tests/test_phase4.sh
./setup.sh doctor
```

자동 테스트는 실제 홈 디렉터리 대신 임시 홈 디렉터리를 사용합니다. 네트워크 설치, 실제 SSH 인증, macOS 전용 설치의 성공을 보장하지 않습니다.

## 10. 문제 해결

| 현상 | 확인 및 해결 |
| --- | --- |
| `Set GITHUB_...` 오류 | `config/profiles.conf`에 해당 프로필 사용자명과 이메일 입력 |
| SSH 인증 실패 | 공개키 GitHub 등록 여부, Host 별칭, 네트워크 확인 후 `doctor github` |
| `gh not installed` | `gh`를 별도 설치하거나 기본 SSH 방식 사용 |
| 기존 저장소 URL 충돌 | `git -C 경로 remote -v`로 확인, 자동 덮어쓰기 없음 |
| Python 설치했지만 `python3` 버전이 다름 | uv 관리 Python과 시스템 Python은 별개. `uv python find 3.12`, `uv venv` 활용 |
| Node 명령이 새 터미널에 없음 | `./setup.sh configure shell` 실행 후 새 zsh 시작 |
| `all`이 일부 실패 | 로그에서 실패 모듈 확인 후 개별 명령으로 재시도 |
| SSH 공개키가 매주 늘어남 | GitHub Settings에서 더 이상 사용하지 않는 키를 확인해 삭제 |

## 11. 권장 운영 수칙

공용 iMac에서는 개인키를 Git 저장소나 공유 폴더에 보관하지 마세요. 매주 초기화 전에 필요한 작업은 GitHub에 push하고, 다른 곳에 보관해야 할 데이터는 기관 정책에 맞게 백업하세요. 이 도구는 파일 백업 도구가 아니며 초기화로 삭제된 로컬 파일을 복구하지 않습니다.
