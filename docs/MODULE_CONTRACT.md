# 모듈 작성 규약 제안

## 등록과 로딩

모듈 하나의 진입점은 `modules/<id>/module.sh`다. 디렉터리명과 ID는 일치해야 하며 ID 형식은 `^[a-z][a-z0-9_]*$`다. 함수는 `<id>_<역할>`로 한정한다. 파일 최상위에서 함수 정의와 등록만 수행한다. Registry는 저장소 밖으로 이어지는 링크를 거부하고 일정한 순서로 탐색한다. source 오류, 파일당 등록 수가 1이 아닌 경우, 중복 ID·키·명령, 빈 이름, 알 수 없는 옵션·플랫폼, 잘못된 함수명을 실행 전에 보고한다. 함수는 declare -F로 확인하고 최종 등록 후 의존 참조를 검사한다. 등록된 함수를 이름으로 직접 호출하며 eval을 사용하지 않는다.

아래는 Phase 6 임시 fixture에 쓸 수 있는 예다. Phase 0에서는 이 API를 설계 대상으로 둔다.

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

## 부수 효과와 테스트

check와 verify는 읽기 전용이다. 설치, 로그인, 셸 설정 수정, 자동 다운로드를 유발하는 탐색을 금한다. apply만 소유 경로와 명시적 대상 저장소를 변경한다. 공유 셸 파일은 공통 helper를 통한다. 재시도 시 기존 키나 다른 origin을 덮어쓰지 않는다. 경로와 부모의 링크를 검사하고 임시 파일은 실패 시 정리한다. 대화가 필요하면 TTY와 명시 옵션을 확인하고 비대화형에서는 원인을 출력한다. 로그에는 ID·단계·간결한 오류를 쓰며 토큰, 개인키, 자격 증명이 포함된 URL은 기록하지 않는다.

새 모듈에는 임시 HOME에서 최초 적용, 두 번째 SKIPPED, 버전 불일치, 진단 실패 시 apply 미호출, apply/verify 실패, 기존 파일 보존을 확인하는 테스트를 둔다. 외부 프로세스는 PATH fixture로 대체하고 실패 단계와 종료 코드도 검증한다.
