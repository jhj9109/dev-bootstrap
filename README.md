# Dev Bootstrap v2

매주 HOME이 초기화되는 교육장 Intel iMac에서 Git 작성자, GitHub 인증 설정, zsh, 개발 도구와 저장소를 복원합니다. 실행기는 Bash이며 관리자 권한 없이 사용자 경로에 설치합니다.

## 처음 실행할 때

```bash
git clone --branch refactor/dev-bootstrap-v2 https://github.com/jhj9109/dev-bootstrap.git
cd dev-bootstrap
cp -n config/accounts.conf.example config/accounts.conf
# 사용할 계정 필드의 주석을 풀고 사용자명과 이메일을 입력합니다.
./setup.sh list
./setup.sh plan --environment minimal --profile personal
./setup.sh check workspace
./setup.sh apply workspace
./setup.sh check workspace
```

기본 Workspace는 `~/Documents`입니다. 새 HOME에서 첫 검사는 `CHANGE_NEEDED`와 코드 1을 반환합니다. 적용 후 검사는 `SKIPPED`와 코드 0입니다. `plan`과 `all --dry-run`은 훅을 실행하지 않습니다. 실제 `all`은 선택한 환경 순서대로 변경하고, 실패한 모듈에 의존하는 항목은 차단하며 독립 항목은 계속합니다.

## 매주 복원할 때

- 개인 설정과 복원할 저장소 목록을 신뢰하는 백업에서 준비합니다. 계정 파일에는 사용자명·이메일만 기록합니다. 기본 인증은 SSH이며 공개키 등록은 사용자가 수행합니다.
- `./setup.sh doctor`로 플랫폼과 도구를 확인합니다. `classroom`은 전체 교육장 구성, 기본 `minimal`은 Workspace·Git·GitHub·Shell입니다. `--profile`은 환경과 독립적으로 계정을 선택합니다.
- `./setup.sh`로 메뉴를 열거나 `./setup.sh help`에서 등록된 명령을 확인합니다. 기존 install/configure/repo 명령과 메뉴 번호 0~11을 계속 사용할 수 있습니다.
- 실제 설치 전 `./setup.sh all --dry-run`으로 대상을 검토합니다. 설치 파일의 출처와 검증 수준은 도구마다 다릅니다. [다운로드 및 복구 한계](docs/DESIGN_AND_LIMITATIONS.md)

계정 설정·셸 이관·복제·오류별 재실행은 [사용 설명서](docs/USER_GUIDE.md), 오프라인 매트릭스와 실기기 검사는 [테스트 지침](docs/TESTING.md), 장비 검증 진행 상태는 [STATUS](STATUS.md)에 있습니다.
