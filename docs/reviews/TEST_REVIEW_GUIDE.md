# Dev Bootstrap 테스트 해설 및 검증 계획

> 기준: Phase 4의 `tests/test_cli.sh`, `test_phase2.sh`, `test_phase3.sh`, `test_phase4.sh`. 아래 설명은 실제 테스트에 포함된 검사만을 근거로 한다.

## 1. 테스트 실행 전 이해할 사항

테스트 스크립트는 `set -euo pipefail`을 사용한다. 조건이 충족되지 않으면 종료되고, 마지막에 `PASS`를 출력한다. 대부분 `mktemp -d`로 임시 디렉터리를 만들고 `trap`으로 종료 시 삭제한다. `HOME`을 임시 경로로 설정하고 실제 사용자 홈에 설치하지 않는다.

**주의**: `HOME` 변경은 완전한 OS 수준 격리가 아니다. 외부 명령이나 사용자 설정이 다른 경로에 접근할 수 있으므로 테스트 소스를 읽고 실행한다. 이 테스트를 관리자 권한으로 실행하지 않는다.

```bash
cd dev-bootstrap
bash -n setup.sh lib/*.sh modules/*.sh modules/auth/*.sh tests/*.sh
bash tests/test_cli.sh
bash tests/test_phase2.sh
bash tests/test_phase3.sh
bash tests/test_phase4.sh
```

Linux 테스트 환경에서 일부 테스트가 통과하더라도 macOS 실기기 검증을 대체하지 않는다.

## 2. 테스트별 Given / When / Then

### T1 — `tests/test_cli.sh`

**Given** 임시 HOME과 복사된 프로젝트. **When** 도움말 출력, 잘못된 명령 실행, `0`을 입력해 메뉴 종료, `doctor` 실행. **Then** 도움말 표시, 잘못된 명령 종료 코드 2, 메뉴 정상 종료, `doctor`가 HOME의 최상위 항목 수를 늘리지 않음.

**실제 증거**: 종료 코드 비교, `grep`, `find ... | wc -l`. **한계**: `doctor`가 기존 파일 내용을 변경하지 않는지 바이트 단위로 비교하지는 않는다. 진단 정확성 전체를 입증하지 않는다.

### T2 — `tests/test_phase2.sh`

**Given** 임시 HOME, 두 GitHub 프로필, 실제 로컬 Git 저장소, 모의 `ssh-keygen` 및 `ssh`, 보존해야 할 `.ssh/config`와 `keep.txt`.

**When** 전역 Git 프로필 설정 → 저장소 로컬 프로필 설정 → SSH 개인 프로필 설정 두 번 → 보조 프로필 설정 → 잘못된 프로필 호출.

**Then** 전역/로컬 `user.name` 분리, 비밀키 해시 불변, SSH Include 한 번, 기존 파일 보존, 두 Host 생성, `.ssh` 권한 700, 잘못된 프로필 종료 코드 2.

**실제 증거**: `git config`, `shasum`, `grep`, `stat`, 파일 존재 검사. **한계**: SSH 키 생성/SSH 설정 해석은 모의 명령으로 검사한다. 진짜 GitHub 연결, 키 암호화 강도, 실제 macOS SSH 동작은 증명하지 않는다.

### T3 — `tests/test_phase3.sh`

**Given** 임시 HOME, 모의 `nvm()` 함수, 모의 `uv` 실행 파일, 기존 `.zshrc` 내용.

**When** 셸 설정 두 번 → Node 24 확인 → uv Python 3.12 확인 → 잘못된 설치 인자 실행.

**Then** `.zshrc` 관리 마커는 한 번, 기존 내용 보존, 이미 설치된 것으로 인식되는 Node/Python 경로 동작, 잘못된 옵션 종료 코드 2, 보존 파일 유지.

**실제 증거**: `grep -Fc`, 파일 내용 비교, 종료 코드 비교. **한계**: Node, Python, uv, iTerm2를 실제 다운로드하거나 설치하지 않는다. 설치 성공, 패키지 무결성, PATH의 실제 셸 적용은 증명하지 않는다.

### T4 — `tests/test_phase4.sh`

**Given** 임시 HOME, 두 GitHub 프로필, 로컬 Git fixture, 모의 SSH 명령.

**When** Workspace 설정 두 번 → Remote 추가/중복/충돌 → Git URL 재작성으로 오프라인 clone 두 번 → 잘못된 repo spec → 설치 비활성화 상태에서 `all` 두 번.

**Then** 기존 Workspace 파일 보존, 동일 Remote 멱등성, 충돌 Remote 미변경, HTTPS 형식 origin을 가진 저장소 복제, 잘못된 입력 거부, `all` 재실행 후 SSH 키와 `.zshrc` 설정 보존.

**실제 증거**: `git remote get-url`, `git config`, 디렉터리/파일 검사, `grep`. **한계**: GitHub 네트워크 접속 없음. `all`에서는 설치 플래그를 `false`로 바꿔 Node/Python/iTerm2를 생략한다. 실패 단계 누적 동작의 모든 조합을 검사하지 않는다.

## 3. 증거 매트릭스

| 요구사항 | 코드 | 기존 테스트 | 실제 보장 범위 |
|---|---|---|---|
| CLI 인자 검증 | `setup.sh` | T1, T3, T4 | 주요 정상/오류 인자 |
| Git 전역/로컬 분리 | `modules/git.sh` | T2 | 로컬 Git에서 검증 |
| SSH 키 재사용 | `modules/auth/ssh.sh` | T2, T4 | 모의 키 파일의 해시 보존 |
| SSH 인증 성공 | `ssh_doctor` | 직접 검증 없음 | 실제 GitHub 테스트 필요 |
| gh 인증 | `modules/auth/gh.sh` | 직접 검증 없음 | gh 로그인 및 계정 선택 실기기 검증 필요 |
| Node 설치 | `modules/node.sh` | T3 | 이미 설치된 것으로 모의한 경로 |
| Python 설치 | `modules/python.sh` | T3 | uv 조회를 모의한 경로 |
| iTerm2 설치 | `modules/iterm.sh` | 직접 검증 없음 | macOS 설치 실기기 검증 필요 |
| Workspace 보존 | `modules/workspace.sh` | T4 | 기존 파일 보존 확인 |
| Remote 충돌 보호 | `modules/repository.sh` | T4 | 실제 로컬 Git에서 검증 |
| 기존 clone 재사용 | `modules/repository.sh` | T4 | Git URL 재작성 이용한 오프라인 검사 |
| 전체 실행 반복 | `setup.sh` | T4 | 설치 비활성화, SSH 모의 상태 |

## 4. 실기기 수동 검증 절차 (권장 순서)

실제 iMac에서 진행할 때는 먼저 기존 SSH 키와 `.zshrc`, Git config의 상태를 확인하고 필요한 경우 안전한 백업을 만든다. 민감한 비밀키 내용을 문서나 채팅에 복사하지 않는다.

1. `./setup.sh doctor`: OS와 필수 도구가 감지되는지 확인. 경고가 의미하는 바를 기록.
2. `./setup.sh configure workspace`: 기존 파일을 임의 삭제하지 않는지 확인.
3. `./setup.sh configure git --profile personal`: `git config --global user.name` 및 `user.email` 확인.
4. `./setup.sh configure github --profile personal`: SSH 키 생성, 권한, Include 및 공개키를 확인. GitHub에 공개키 등록.
5. `./setup.sh doctor github --profile personal`: 실제 GitHub 인증 결과 확인.
6. 필요하다면 보조 프로필도 같은 순서로 검증. 실제 GitHub 계정이 올바른지 확인.
7. `./setup.sh install node`: `zsh -lic 'node --version; npm --version'` 등 **새로운 셸**에서 확인.
8. `./setup.sh install python`: `~/.local/bin/uv python find 3.12 --no-python-downloads`로 설치 확인. 프로젝트 가상환경 동작도 별도 확인.
9. `./setup.sh install iterm`: `~/Applications`에 앱이 있는지 확인하고 실제 실행 여부 확인.
10. `./setup.sh repo clone OWNER/REPO`: 테스트용 개인 저장소에서 실행. 원격 주소, 브랜치, 작업 트리 확인.
11. 개별 검증을 마친 후에만 `./setup.sh all`을 사용하고 각 단계 결과를 기록.

**안전 주의**: 위 명령 중 `configure`, `install`, `repo`, `all`은 실제 파일과 Git 설정을 변경한다. 실기기 검증은 허용된 개인 계정에서 수행한다. `--no-passphrase`는 기본 테스트 방식으로 권장하지 않는다.

## 5. 반드시 추가할 테스트 제안

- **실패 주입**: Git `user.email` 설정 실패, 다운로드 중단, 파일 쓰기 권한 거부, `all` 단계별 실패 후 후속 단계 진행.
- **실제 macOS**: SSH 키 생성/파싱, `zsh` 초기화, `ditto` 추출, 앱 실행, Xcode CLT.
- **보안**: symlink 거부, 설정 파일 신뢰 경계, 원격 다운로드 검증, 로그의 비밀 정보 노출.
- **데이터 보존**: 기존 `.ssh/config`, `.zshrc`, Git 설정, 프로젝트 작업 트리의 실행 전후 해시/상태 비교.
- **회귀 테스트**: 두 계정의 SSH/gh 인증 전환, GitHub 계정 불일치, origin 충돌, 동일 이름의 다른 소유자 저장소.

## 6. 테스트 리뷰 기록 예시

```text
테스트: T2 — SSH 키 재사용
요구사항: 두 번째 실행 시 기존 키를 덮어쓰지 않는다.
Given: 키 생성 완료, 기존 파일 존재
When: 동일한 configure github 명령 재실행
Then: 비밀키 SHA-256 동일, SSH Include 1회
테스트가 증명하는 것: 모의 SSH 환경에서 파일 보존
증명하지 못하는 것: 실제 키의 암호학적 유효성, GitHub 인증
추가 실험: macOS에서 실제 ssh-keygen/ssh -G/ssh -T 검증
판정: 부분 검증
```
