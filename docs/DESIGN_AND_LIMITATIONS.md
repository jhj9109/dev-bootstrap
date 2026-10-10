# Dev Bootstrap — 설계 및 운영 참고

## 구성

- `setup.sh`: CLI 인자 해석, 메뉴, 전체 실행 순서
- `lib/config.sh`: 기본값 및 개인 설정 로드, 주요 설정 검증
- `lib/profiles.sh`: personal/secondary GitHub 계정 프로필
- `lib/platform.sh`: 비파괴 진단 (`doctor`)
- `modules/auth/ssh.sh`: 키 및 SSH Host 구성
- `modules/auth/gh.sh`: GitHub CLI HTTPS 인증
- `modules/git.sh`: Git 작성자 설정
- `modules/node.sh`, `python.sh`, `shell.sh`, `iterm.sh`: 개발 도구 설치
- `modules/workspace.sh`: Workspace 디렉터리 관리
- `modules/repository.sh`: clone, remote 추가

## 실행 흐름

`all`: Workspace → Git 작성자 → GitHub 인증 → Shell → Node → Python → iTerm2 → 선택적 저장소 목록 복제 → 실패 건수 요약. 설치 옵션 `INSTALL_*`이 false면 해당 단계 생략. 개별 단계 실패 시 다른 단계는 계속 진행하지만 전체 종료 코드는 실패가 됩니다.

## 안전성 원칙

1. 기존 SSH 키 및 사용자 설정 파일은 무조건 삭제하지 않습니다.
2. SSH 관리용 설정은 별도 파일로 분리하고 기존 config에는 Include를 추가합니다.
3. 이미 존재하는 저장소 또는 원격 URL이 다르면 자동 덮어쓰지 않습니다.
4. doctor는 변경하지 않습니다.
5. 임시 HOME 기반 테스트로 멱등성을 확인합니다.

## 알려진 한계

- 현재 `all`은 완전한 무인 자동화가 아닙니다. SSH 키 암호 입력과 GitHub 공개키 등록이 필요합니다.
- SSH 공개키의 GitHub 등록/폐기 자동화는 없습니다.
- `gh` CLI 설치는 제공하지 않으며, 다중 HTTPS 계정별 자동 인증 매핑도 없습니다.
- nvm, uv 설치 스크립트와 iTerm2 다운로드에 대해 독립적인 체크섬·서명 검증을 구현하지 않았습니다.
- macOS 실제 장비의 다운로드·설치 및 인증 성공은 아직 검증되지 않았습니다.
- `all`은 실패한 단계를 재시도하는 상태 파일이나 트랜잭션 롤백 기능이 없습니다. 명령을 다시 실행하면 각 모듈의 상태 검사를 활용합니다.
- 저장소 목록은 기본 프로필/인증 방식 하나를 공유하며 저장소별 프로필 지정은 지원하지 않습니다.
- `repo clone`은 이미 존재하는 저장소의 origin만 검사하고 fetch/pull하지 않습니다.
- `repo remote`는 기존 remote URL을 변경하지 않습니다.
- 일부 설정 검증은 형식 중심이며, 모든 파일 시스템 경로·심볼릭 링크 조합을 포괄적으로 방어하지 않습니다. 신뢰할 수 있는 사용자 환경에서 실행해야 합니다.
- Python uv 설치가 시스템 기본 `python3` 명령을 대체하지는 않습니다.
- iTerm2는 최신 stable URL을 사용하므로 정확한 버전 재현성이 없습니다.

## 향후 개선 우선순위

1. macOS 실기기 설치/인증 검증 및 설치 파일 체크섬 검증
2. `--dry-run`, `--yes`, 실행 로그 파일, 재시도 옵션
3. 설치 버전 잠금 및 플랫폼별 아티팩트 검증
4. 저장소 목록에 프로필/브랜치/목적지 설정 지원
5. GitHub CLI 설치와 안전한 다중 계정 지원
6. ShellCheck, Bats 기반 테스트 및 macOS CI
