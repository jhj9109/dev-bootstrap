# Dev Bootstrap v1.0 — Phase 4

공용 macOS iMac에서 매주 삭제되는 개인 홈 디렉터리의 개발 환경을 다시 구성하기 위한 Bash 도구입니다. **기본 GitHub 인증은 SSH**이며 `gh` CLI를 대체 방식으로 지원합니다. 관리자 권한 없이 실행하는 것을 목표로 합니다.

> 사용 전 반드시 [사용 설명서](docs/USER_GUIDE.md)를 읽으세요. 특히 `all`은 설치 파일 다운로드와 사용자 환경 변경을 수행합니다. GitHub 공개키 등록은 자동으로 수행하지 않습니다.

## 빠른 시작

```bash
git clone https://github.com/OWNER/dev-bootstrap.git # 실제 게시한 저장소 주소로 교체
cd dev-bootstrap
cp config/profiles.conf.example config/profiles.conf
# config/profiles.conf에 사용자명과 이메일을 입력
./setup.sh doctor
./setup.sh                  # 대화형 메뉴
./setup.sh all              # 전체 구성; 인증 단계에서 사용자 입력 필요
```

## 명령

```bash
./setup.sh help
./setup.sh doctor
./setup.sh doctor github --profile personal
./setup.sh configure git --profile personal
./setup.sh configure github --profile personal          # SSH 기본
./setup.sh configure github --profile secondary
./setup.sh configure github --method gh --profile personal
./setup.sh configure shell
./setup.sh configure workspace
./setup.sh install node --version 24
./setup.sh install python --version 3.12 --method uv
./setup.sh install python --version 3.12.7 --method source
./setup.sh install iterm
./setup.sh repo clone OWNER/REPO --profile personal
./setup.sh repo clone OWNER/REPO --method gh
./setup.sh repo clone OWNER/REPO --dest /absolute/path
./setup.sh repo remote OWNER/REPO --repo /absolute/existing/repo --name origin
./setup.sh all --profile personal
```

기본 Workspace는 `~/Documents`입니다. `repo clone`은 목적지가 존재하고 동일한 `origin`을 가진 Git 저장소라면 건너뜁니다. `repo remote`는 기존 원격 주소가 다를 때 덮어쓰지 않습니다.

## 저장소 일괄 복원

```bash
cp config/repositories.conf.example config/repositories.conf
```

`config/repositories.conf`에 `OWNER/REPO`를 한 줄씩 입력하세요. `./setup.sh all` 실행 시 기본 프로필과 인증 방식으로 복제합니다. 복제 목적지 이름이 중복되면 충돌이 발생하므로 별도로 관리하세요.

## 설정 및 보안

- `config/defaults.conf`: 버전 관리되는 기본값. `INSTALL_NODE`, `INSTALL_PYTHON`, `INSTALL_ITERM`을 `false`로 설정하면 `all`에서 제외합니다.
- `config/profiles.conf`: 개인 GitHub 사용자 이름과 커밋 이메일. `.gitignore`로 제외됩니다.
- `config/repositories.conf`: 개인 복제 목록. `.gitignore`로 제외됩니다.
- `.conf` 파일은 Bash로 `source`되므로 **신뢰할 수 있는 내용만** 작성하세요.
- SSH 개인키, 액세스 토큰, 비밀번호는 Git에 커밋하지 마세요.
- SSH 개인키는 `~/.ssh/dev-bootstrap-personal` / `...-secondary`에 생성합니다. 기존 키를 덮어쓰지 않습니다.
- SSH 키는 GitHub Settings → SSH and GPG keys에 직접 등록하고 `doctor github`로 검증해야 합니다.
- `--no-passphrase`는 SSH 키를 암호화하지 않고 생성하므로 공용 기기에서 사용을 권장하지 않습니다.
- 매주 홈 디렉터리가 초기화된다면 GitHub에 사용하지 않는 SSH 공개키가 누적될 수 있으므로 정리해야 합니다.
- `gh` 방식은 사전에 `gh`가 설치되어 있어야 하며, 여러 계정은 `gh auth switch`로 활성 계정을 직접 선택해야 합니다.
- Node는 nvm, Python은 uv(기본) 또는 소스 빌드, iTerm2는 `~/Applications`를 사용합니다. 다운로드 무결성 검증은 아직 강화가 필요합니다.

## 테스트

```bash
bash -n setup.sh lib/*.sh modules/*.sh modules/auth/*.sh tests/*.sh
bash tests/test_cli.sh
bash tests/test_phase2.sh
bash tests/test_phase3.sh
bash tests/test_phase4.sh
```

테스트는 임시 HOME을 사용합니다. 네트워크 설치와 실제 GitHub 인증을 검증하지 않으며, macOS 실기기에서 추가 확인해야 합니다.

## 문서

- [사용 설명서](docs/USER_GUIDE.md): 최초 설치, 매주 복구, 명령어, 문제 해결
- [설계 및 운영 참고](docs/DESIGN_AND_LIMITATIONS.md): 구성 요소, 동작 규약, 한계, 향후 개선
