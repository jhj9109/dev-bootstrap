# v2 모듈 작성 규약

## 등록과 로딩

모듈 하나의 진입점은 `modules/<id>/module.sh`다. 디렉터리명과 ID는 일치해야 하며 ID 형식은 `^[a-z][a-z0-9_]*$`다. 함수는 `<id>_<역할>`로 한정한다. 파일 최상위에서 함수 정의와 등록만 수행한다. Registry는 저장소 밖으로 이어지는 링크를 거부하고 일정한 순서로 탐색한다. source 오류, 파일당 등록 수가 1이 아닌 경우, 중복 ID·키·명령, 빈 이름, 알 수 없는 옵션·플랫폼, 잘못된 함수명을 실행 전에 보고한다. 함수는 declare -F로 확인하고 최종 등록 후 의존 참조를 검사한다. 등록된 함수를 이름으로 직접 호출하며 eval을 사용하지 않는다.

아래는 설정 키와 파일 목표를 가진 일반 모듈의 등록 예다.

```bash
sample_defaults() { SAMPLE_VERSION=1; }
sample_validate() { [[ "$SAMPLE_VERSION" =~ ^[0-9]+$ ]]; }

sample_check() {
  local path="$HOME/.dev-bootstrap-sample" actual
  [[ ! -L "$path" ]] || return 1
  [[ -e "$path" ]] || return 10
  [[ -f "$path" ]] || return 1
  actual="$(cat "$path")" || return 1
  [[ "$actual" == "$SAMPLE_VERSION" ]] || return 10
}

sample_apply() (
  local tmp
  umask 077
  tmp="$(mktemp "$HOME/.dev-bootstrap-sample.XXXXXXXX")" || return 1
  trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$SAMPLE_VERSION" > "$tmp" || return 1
  mv "$tmp" "$HOME/.dev-bootstrap-sample"
)

register_module --id sample --name "예제 도구" --platforms "Darwin Linux" \
  --keys SAMPLE_VERSION --defaults sample_defaults --validate sample_validate \
  --check sample_check --apply sample_apply --verify sample_check
```

`--id/--name/--platforms/--check/--apply/--verify`는 필수다. `--depends "workspace git"`는 공백 구분 ID 목록으로 기본값은 빈 목록이다. 설정이 있으면 `--keys/--defaults/--validate`를 함께 등록한다. 키는 모듈별 접두사가 있는 대문자 스칼라이며 공통 키 및 셸 예약 이름과 충돌하면 등록 실패다. 환경의 ENABLED_MODULES 배열은 Planner 입력이다. 특수 명령은 별도 등록한 작업 함수에 원본 인자 배열을 넘긴다.

### T16 일괄 실행 계획

`--depends`에는 일괄 실행에서 먼저 끝나야 하는 모듈 ID를 등록한다. `--depends-if 'PYTHON_INSTALL_METHOD=uv'`처럼 조건을 붙이면 모듈 자신이 등록한 설정 키가 지정한 값과 일치할 때만 해당 선행 목록 전체를 사용한다. Registry는 조건의 키와 모든 참조 ID를 검사하고 Planner는 확정된 설정값으로 조건을 해석한다. `--prerequisites`는 실행에 필요한 도구와 접근 권한을 설명하는 표시용 텍스트다.

| 대상 | 일괄 계획의 선행 모듈 | 실행 시 필요한 조건 |
|---|---|---|
| Node | shell | nvm이 없으면 curl과 Bash로 설치한다. |
| Python | uv 방식이면 shell, source 방식이면 없음 | 소스 설치에는 패치 버전까지 지정한 Python과 빌드 도구가 필요하다. |
| Repository | workspace | 목록 복원은 기본 목적지를 사용한다. 복제에는 Git 실행 파일과 대상 저장소 읽기 권한이 필요하다. SSH 로컬 설정 후에도 원격 키 등록이 필요할 수 있다. |
| Git, GitHub, Shell, iTerm2, Workspace | 없음 | Git 작성자 설정과 원격 인증은 별도 작업이다. gh 인증과 셸 조각 관리에서 사용하는 Git은 실행 파일 요구사항이다. |

Planner는 확정된 `ENABLED_MODULES`의 순서와 범위를 보존한다. 선택된 의존성이 빠졌거나 뒤에 있으면, 또는 ID 중복·자기 참조·순환이 있으면 코드 2로 중단한다. `plan`과 `all --dry-run`은 같은 경로에서 모든 검증에 성공한 뒤 계획을 출력한다. 표시된 플랫폼·외부 도구·원격 권한은 실행 조건이며 조회 시 설치 상태나 인증 여부를 검사하지 않는다. 기존 개별 명령은 환경 목록과 독립적으로 실행하며 Node·uv의 개별 Shell 복구와 명시적 목적지의 복제 동작을 유지한다.

### T11 설정 소유권과 재로딩

Workspace는 `WORKSPACE_DIR`, Node는 `NODE_VERSION`, Python은 `PYTHON_VERSION`과 `PYTHON_INSTALL_METHOD`를 등록한다. 여러 모듈이 공유하는 대상 OS·기본 계정·인증 방식·기존 계정 필드와 `all`의 세 `INSTALL_*` 플래그는 공통 설정이다. Registry는 공통 키, 셸·실행 문맥의 예약 이름, 이미 등록된 키를 거부한다.

매번 공통 키와 등록 키를 비운 후보 셸에서 시작한다. 위치 인자 없이 호출되는 `defaults`는 등록한 키 **전부**에 문자열을 할당한다. 빈 문자열도 값이다. 로더는 그 훅이 소유한 키만 가져온다. 기본값 위에 기존 `config/defaults.conf`, 있으면 `config/profiles.conf`를 순서대로 적용한다. `validate`는 완성된 후보를 읽고 성공 시 0, 실패 시 비영 코드를 반환한다. 각 검증은 독립된 서브셸에서 실행한다. 두 종류의 훅 모두 파일 변경·설치·네트워크 호출을 하지 않는다.

로더는 예상한 순서대로 모든 키·값의 NUL 구분 레코드를 읽고 쓰기 가능한 문자열인지 확인한 뒤 부모 셸에 일괄 반영한다. 설정 오류는 코드 2이며 마지막 정상 설정 전체를 보존한다. 메뉴는 재로딩에 실패한 선택의 실행을 건너뛴다.

### T12 환경 설정

활성 환경 이름 `ENVIRONMENT`와 `ENABLED_MODULES`는 로더가 관리한다. 모듈 훅은 선택된 환경과 최종 목록을 읽을 수 있다. 공통 defaults와 개인 profiles 사이에 선택한 환경 파일을 적용한다. 목록은 0부터 연속한 인덱스를 갖는 배열이며 각 원소는 서로 다른 등록 ID여야 한다. `classroom`에서 목록이 미설정이면 로더가 기존 `INSTALL_*`를 변환한다. 명시한 빈 배열의 길이는 0이다.

스냅샷의 각 필드는 NUL로 구분한다. 스칼라 레코드는 키·종류·값, 배열 레코드는 키·종류·원소 수·순서대로 나열한 원소를 담는다. 확정 스냅샷에는 해석을 마친 배열이 필요하다. 수신 측은 선언된 키와 종류, 개수, ID, 끝 경계를 확인한 뒤 스칼라와 배열을 함께 교체한다.

## 호출과 판정

일반 훅은 위치 인자 없이 호출한다. 모듈은 확정된 공통 설정, 자기 키와 실행 문맥(환경명, 선택 계정, 인증 방식, 비대화형 여부)을 읽는다. defaults만 자기 기본값을 기록한다. validate는 후보 설정을 읽고 0 또는 오류를 반환한다. 실행 훅은 각각 같은 확정 설정을 받은 서브셸에서 호출한다. 훅 간 지속 상태는 설치 파일 등 명시한 산출물로 확인한다.

| 단계 | 반환과 Runner 동작 |
|---|---|
| 선행 확인 | 플랫폼 불일치면 UNSUPPORTED. 선행 모듈 실패·누락 도구는 BLOCKED로 요약한다. 독립 항목은 계속 실행한다. |
| check | 0이면 목표 충족으로 SKIPPED, 10만 변경 필요를 뜻한다. 4는 NEEDS_ACTION, 3은 BLOCKED, 나머지 오류는 FAILED다. 읽기 실패와 버전 불일치를 각각 구분한다. |
| apply | check가 10일 때만 호출한다. 0이면 verify로 진행하고 3·4는 위 상태로 보낸다. 그 밖의 비정상 종료는 FAILED다. |
| verify | 변경 후 같은 버전·설정·권한을 재확인한다. 0이면 SUCCESS, 여전히 미충족이면 FAILED다. 외부 사용자 조치와 누락 도구는 4·3으로 전달한다. |

Phase 1의 `runner_run <id>`는 SUCCESS와 SKIPPED에 0을, 나머지 상태에 1을 반환한다. 호출 직후 `RUNNER_STATUS`에서 상태를, `RUNNER_PHASE`에서 마지막 단계를, `RUNNER_HOOK_STATUS`에서 해당 훅이 반환한 원본 코드를 읽을 수 있다. 조회나 플랫폼 검사에서 종료하면 훅 코드는 빈 값이다. 기존 CLI는 이 결과를 명령별 종료 코드로 변환한다.

예를 들어 Node는 요청 버전 해석 결과, default alias와 필요한 셸 조각을 확인한다. 실행 파일을 읽을 수 없는 상황은 진단 실패다. SSH 로컬 키·별칭 구성과 원격 계정 검증은 독립 작업이다. 원격 인증을 요구하는 작업에서 등록이 필요하면 NEEDS_ACTION을 반환한다. 기존 configure github의 로컬 완료 의미는 호환 어댑터가 보존한다.

`check` 명령은 변경 필요를 표시하고 비영 종료하며 apply를 호출하지 않는다. `plan`과 `all --dry-run`은 설정·계획 검증과 대상·순서·선행 조건 표시에 한정한다. 실행 요약은 각 ID, 상태, 실패 단계·사유와 재실행 명령을 담는다. 새 집계 CLI는 모든 목표 충족 시 0, 실행 미완료 시 1, 입력·설정·계획 오류 시 2다. 기존 단일 명령의 종료 코드는 호환 테스트로 고정한다.

### T17 실행 문맥과 집계

`runner_run <id> [apply|check]`는 두 모드에서 같은 플랫폼 검사와 check 훅을 사용한다. check 전용 모드에서 코드 10은 `CHANGE_NEEDED`로 끝난다. `SUCCESS`와 `SKIPPED`만 후행 훅의 실행을 허용한다. Runner는 읽기 전용 선행 검사 결과도 요약에 포함하며 `BLOCKED` 행에 직접 선행 ID와 그 상태를 기록한다. 실행 훅에서 나온 오류는 해당 단계·원본 코드와 함께 미완료(1)로 집계한다.

범용 명령의 훅은 `PROFILE`, `METHOD`, `NO_PASSPHRASE`에서 확정한 계정·인증 방식·SSH 키 정책을 읽는다. CLI가 기존 훅에 전달하는 지역 변수는 다음과 같다.

| 훅 | 실행마다 확정하는 값 |
|---|---|
| Git | `identity_profile`, `identity_scope`, `identity_repo`. 단일 Git의 로컬 범위와 경로를 포함한다. |
| GitHub | `github_profile`, `github_method`, `github_unencrypted`. SSH 로컬 완료와 원격 계정 검증은 별개다. |
| Node·Python | `node_request`, `python_request`, `python_method`. 명시한 버전·방식을 해당 호출의 설정에 먼저 반영해 Planner와 훅이 같은 전략을 본다. |
| Shell | 일괄 적용과 단일 Shell 대상은 환경의 활성 조각을 기준으로 삼는다. 단일 Node·uv의 선행 확인은 기존 목록에 요청한 조각이 활성화돼 있는지 검사한다. |
| Repository | `repository_profile`, `repository_method`, `repository_snapshot`. 실행 대상 또는 검사할 선행에 포함되면 첫 훅 전에 복원 목록을 한 번 읽는다. 빈 목록도 확정된 스냅샷이다. |

`RUNNER_PLANNED=1`인 범용 실행에서는 선행 상태가 도중에 달라져도 Node·uv가 Shell을 복구하거나 Repository가 Workspace를 만들지 않는다. 기존 개별 명령은 해당 어댑터에서 복구와 종료 코드 변환을 수행한다.

## 부수 효과와 테스트

check와 verify는 읽기 전용이다. 설치, 로그인, 셸 설정 수정, 자동 다운로드를 유발하는 탐색을 금한다. apply만 소유 경로와 명시적 대상 저장소를 변경한다. 공유 셸 파일은 공통 helper를 통한다. 재시도 시 기존 키나 다른 origin을 덮어쓰지 않는다. 경로와 부모의 링크를 검사하고 임시 파일은 실패 시 정리한다. 대화가 필요하면 TTY와 명시 옵션을 확인하고 비대화형에서는 원인을 출력한다. 로그에는 ID·단계·간결한 오류를 쓰며 토큰, 개인키, 자격 증명이 포함된 URL은 기록하지 않는다.

새 모듈에는 임시 HOME에서 최초 적용, 두 번째 SKIPPED, 버전 불일치, 진단 실패 시 apply 미호출, apply/verify 실패, 기존 파일 보존을 확인하는 테스트를 둔다. 외부 프로세스는 PATH fixture로 대체하고 실패 단계와 종료 코드도 검증한다.

### T18 명령 등록과 메뉴

모듈은 `register_module`과 함께 `register_command 'repo clone' repository_command_clone 'OWNER/REPO [options]'` 형식으로 특수 명령을 등록할 수 있다. 명령 이름은 공백 하나로 구분한 두 ID이며 처리 함수는 소유 모듈의 접두사를 사용한다. CLI는 전역 환경 선택을 처리하고 명령 이름 뒤의 인자를 배열 그대로 전달한다. 중복 명령·예약 명령·정의되지 않은 함수는 탐색 오류다.

기존 호환 명령은 등록 끝에 고정 번호(2~9)와 메뉴 문구를 지정한다. 메뉴는 설정을 다시 읽은 뒤 같은 처리 함수를 인자 없이 호출한다. 고정 항목이 없는 모듈은 C 로캘의 디렉터리 탐색 순서로 12부터 번호를 받고 단일 apply를 실행한다. 0·1·10·11은 각각 종료·환경 검사·전체 적용·도움말이다.
