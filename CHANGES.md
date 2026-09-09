# NavilIME 개인 수정 기록

이 프로젝트는 **Manwoo Yi**([@navilera](https://github.com/navilera))님이 만든 macOS용 한글 입력기입니다.
세벌식 318Na 자판을 직접 디자인하고, 리눅스/윈도우/맥 전부 입력기를 직접 구현하신 분입니다.
아래는 개인 용도로 포크하여 수정한 내용입니다.

원본: [navilera/NavilIMEforMac](https://github.com/navilera/NavilIMEforMac)

## 2026-09-09 - 내부 한/영 모드 제거, 입력 소스로 일원화

- `self_eng_mode`(입력기 내부 한/영 플래그)와 전용 단축키를 전부 제거했다.
  `ToggleSuspend`, `OptHandler`(`SingletonOpt.swift` 삭제), 트레이의 "한/영 전환" 섹션,
  `select_haneng_hotkey` 제거. 순 -62줄.
- 한/영은 macOS 입력 소스 선택으로만 결정된다. 한글 = NavilIME, 영문 = ASCII 레이아웃(ABC).
- 내부 모드는 macOS가 알 수 없는 상태였다. 어느 앱에서든 "NavilIME 선택됨"으로만 보여
  OS가 앱별 기억도 암호 필드 대응도 해줄 수 없었고, 이 세션에서 겪은 문제들의 공통 뿌리였다.
- 전환 비용은 2.5ns → 약 1.29ms(측정 중앙값)로 늘지만 인지 한계(~10ms) 아래다.
- 앱별 지정은 `NSWorkspace.didActivateApplicationNotification`으로 적용한다.
  `activateServer`는 선택된 입력기에만 오므로, 입력 소스가 ABC일 때는 알림이 유일한 경로다.
- '영문' 지정인데 이미 ABC면 아무것도 하지 않는다 — 결과가 같고 사용자의 소스 선택을
  뒤엎을 이유가 없다.

### 검증 중 발견: 옛 샌드박스 컨테이너
- `~/Library/Containers/com.navilera.inputmethod.NavilIME/`가 남아 있다. 샌드박스를
  끄기 전 시절의 잔재로, `defaults` 명령은 이 컨테이너를 읽고 쓰는 반면 앱은
  `~/Library/Preferences/`를 쓴다. 옛 설정(`keyboard`, `002_sel_no_shift`)이 컨테이너에
  갇혀 있고 앱은 못 읽는다. 지금 코드에는 없는 설정이라 실사용 영향은 없다.

## 2026-09-09 - 앱별 한/영 고정

- 이 입력기의 한/영은 입력 소스 전환이 아니라 `self_eng_mode` 플래그를 뒤집는 방식이라,
  macOS 입장에선 어느 앱에서든 "NavilIME 선택됨"으로 동일하게 보인다. 그래서 OS의
  "문서의 입력 소스로 자동 전환"이 이 상태를 기억해줄 수 없다. 입력기가 직접 기억한다.
- `AppLangHandler`: 번들 ID → `지정 안 함`/`한글`/`영문`. 지정한 앱만 저장하고,
  해제하면 키 자체를 지운다. `UserDefaults`(`app_lang_map`)에 영속화.
- `activateServer`에서 클라이언트 번들 ID를 읽어 지정값이 있으면 모드를 맞춘다.
  지정 안 한 앱은 건드리지 않으므로 기존 동작 그대로다.
- 트레이 메뉴에 "‘앱이름’에서 항상" 섹션 추가. `menu()`에는 클라이언트가 넘어오지 않아
  마지막 클라이언트 번들 ID를 static으로 남겨 쓴다.
- 앱 안에서 수동 전환하면 그게 이기고, 다시 들어올 때 지정값으로 복귀한다.

### 측정 정정
- 이전 회차에서 "비활성 로그가 이벤트당 21.5ns"라고 적었으나 오측이었다. 벤치마크
  하네스를 `-wmo` 없이 컴파일한 탓이고, 실제 Release는 `SWIFT_COMPILATION_MODE =
  wholemodule`이라 최적화기가 오토클로저를 완전히 제거한다. 실제 비용은 0ns다.
- 같은 조건에서 한영전환 전체 경로는 약 2.5ns(`Is_han_eng_changed` 1.44ns +
  `ToggleSuspend` 1.11ns). 비교로 macOS 입력 소스 전환은 중앙값 1.29ms.

## 2026-08-31 - Release 빌드에서 get-task-allow 제거

- Xcode는 Apple Development 인증서로 서명할 때 `com.apple.security.get-task-allow`를
  자동 주입한다(`CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES`). 이건 "다른 프로세스가
  디버거를 붙여도 된다"는 뜻이라, Hardened Runtime(`flags=0x10000(runtime)`)이
  켜져 있어도 디버거 접근이 열린다.
- 입력기는 모든 키 입력을 지나보내고 손쉬운 사용 권한까지 갖고 있으므로, 사용자 권한으로
  도는 악성코드가 여기에 붙어 키 입력을 읽거나 이 앱의 TCC 권한에 편승할 수 있다.
- `Signing.xcconfig`에 `CODE_SIGN_INJECT_BASE_ENTITLEMENTS[config=Release] = NO`를
  추가해 Release에서만 주입을 끈다. Debug는 Xcode 디버깅을 위해 그대로 둔다.
- 확인: Release 빌드의 entitlements가 `app-sandbox = false` 하나만 남았다.

## 2026-08-31 - 터미널 암호 프롬프트 자동 감지 (TTYPasswordWatcher)

### sudo 외에 ssh·git·passwd 등도 커버, 셸 설정 불필요
- 기존 방식(`secure-run` + `.zshrc` 래퍼)은 명령별로 감싸야 했고 `sudo`만 실용적이었다.
  `ssh`는 세션 전체를 감싸게 되어 원격 접속 내내 한글을 못 쓰게 되므로 쓸 수 없었다.
- 비밀번호를 읽는 프로그램은 tty를 **정규 모드(ICANON) + 에코 끔(ECHO off)** 으로 만들고,
  전체화면 TUI는 raw 모드(ICANON off)라 구분된다. 실측 확인:

  | 프로그램 | 모드 | 에코 | 판정 |
  |---|---|---|---|
  | `cat` | 정규 | on | — |
  | `getpass` | 정규 | OFF | 암호 프롬프트 |
  | `vi` | raw | OFF | TUI (오탐 아님) |
  | `top` | raw | OFF | TUI (오탐 아님) |

- `TTYPasswordWatcher`가 사용자 소유 `/dev/ttys*`를 훑어 이 상태를 찾으면
  `EnableSecureEventInput()`을 켠다. 조합이 멈추는 것은 물론, 그동안 다른 앱의
  이벤트 탭까지 차단되어 실제 키로거 방어가 된다. 조건이 풀리면 즉시 해제하고,
  앱 종료 시에도 해제한다(우리가 켠 만큼만 끄도록 보유 여부를 추적).
- tty는 `O_NOCTTY | O_NONBLOCK`으로 열어 controlling terminal이 되지 않게 한다.
- 비용: 1회 스캔 약 515µs(대부분 tty open 비용, 하나당 ~57µs — 목록을 캐시해도 줄지 않음).
  타이머는 1초 주기(약 0.05% CPU), 키 입력 경로는 100ms TTL 캐시로 확인해 프롬프트 직후
  첫 글자도 놓치지 않는다.
- 종단 검증: pty로 `getpass`를 띄우면 secure input이 켜지고 종료 시 해제, `top`(TUI)에는
  반응하지 않음을 확인.
- `Tools/secure-run`은 감지가 안 먹는 상황용 수동 탈출구로 남긴다.
- `Tools/tty-password-log.py`: 같은 조건을 독립적으로 감시해 언제 어떤 프로그램이
  암호 프롬프트 상태를 만들었는지 기록한다. 오탐 추적용.

## 2026-08-31 - 암호 프롬프트에서 입력기 자동 비켜서기

### 한글 상태에서 sudo 비밀번호가 안 들어가던 문제
- macOS는 secure input이 켜져도 **입력 소스를 영문으로 갈아주지 않는다**(측정으로 확인:
  sudo 프롬프트 동안 `IsSecureEventInputEnabled() == true`인데 현재 입력 소스는
  `com.navilera.inputmethod.NavilIME` 그대로였다). 그래서 한글 상태면 암호가 한글로
  들어가고, 사용자가 매번 수동으로 영문 전환해야 했다.
- `keydown_event_handler` 진입부에서 `IsSecureEventInputEnabled()`를 확인해, 켜져 있으면
  조합 없이 키를 그대로 통과시킨다(`Flush()` 후 `return false`).
- 한/영 상태(`ToggleSuspend`)는 건드리지 않는다. 프롬프트를 빠져나오면 원래 한글 상태로
  자동 복귀한다.
- 호출 비용은 약 4ns(로컬 플래그 읽기)로 측정돼 매 키 입력 경로에 두어도 무방하다.
- 부작용: secure input은 프로세스 전역 참조 카운트라, 어떤 앱이 켜놓고 끄지 않으면 한글이
  어디서도 조합되지 않는다. 화면 잠갔다 풀면 해소된다.

### 터미널 sudo용 보조 도구 `Tools/secure-run`
- 측정 결과 터미널의 sudo 프롬프트는 secure input을 켜지 않는다(터미널이 pty 에코 상태를
  보지 않음). 그래서 위 수정만으로는 sudo 자리가 메워지지 않는다.
- `secure-run <명령>`: 그 명령이 도는 동안만 secure input을 켠다. 어떤 시그널로 끝나든
  `atexit`/시그널 핸들러로 반드시 되돌린다(켠 채 죽으면 시스템 전역으로 남기 때문).
- `Tools/zshrc-snippet.sh`의 sudo 래퍼는 `sudo -v`(암호 확인만 하고 즉시 종료)를 감싸므로
  프롬프트 동안만 잡힌다. `sudo vim` 편집 중에는 한글이 정상 동작한다.
- `Tools/install.sh`로 `~/.local/bin`에 빌드·설치.
- 자식은 `posix_spawnp`를 attr 없이 직접 호출해 띄운다. Foundation의 `Process`는 자식을
  새 프로세스 그룹(세션)에 넣는데, 그러면 자식이 포그라운드 그룹이 아니게 되어 sudo가
  tty에서 암호를 읽으려는 순간 `SIGTTIN`으로 멈춘다 — 프롬프트만 찍히고 입력이 안 먹는
  증상이 된다. 부모의 프로세스 그룹과 controlling tty를 그대로 물려줘야 한다.
- 자식의 종료 상태(정상 종료 코드 / 시그널)를 그대로 전달한다.
- `Tools/secure-test`: secure input을 켠 채 에코를 남겨두고 한 줄을 받아, 비밀번호 없이
  입력기가 비켜서는지 눈으로 확인하는 회귀 테스트 도구.

## 2026-08-31 - 특수키 처리 경로 통합

### 한글 입력 중 `` ` ``, `₩`가 나오지 않던 문제
- 원인: ⌘ 조합 키 이벤트는 AppKit의 키 이퀴벌런트 단계에서 소비되어
  `IMKInputController.handle`까지 내려오지 않는다. NavilIME 활성(한글) 상태에서는
  `SpecialKeyTap`이 IMK 경로에 처리를 양보했으므로 아무도 처리하지 않았다.
  (`Shift+ESC→~`는 키 이퀴벌런트가 아니라 IMK에 도달해 정상 동작했다.)
- 조치: `SpecialKeyTap`을 특수키 조합의 유일한 처리 경로로 통합. 탭이 세션 레벨에서
  모디파이어를 지우고 유니코드를 갈아끼우므로, 치환된 이벤트는 평범한 키가 되어
  입력기 상태와 무관하게 동작한다.
- `NavilIMEInputController.special_keys` 사본 테이블과 처리 루프 제거.
  `SpecialKeyTap.currentInputSourceIsNavil()`(TIS 조회)과 `import Carbon`도 함께 제거.
- 치환된 이벤트는 keycode가 아니라 `event.characters`가 진실이다. 탭은 모디파이어만
  지우므로 keycode는 원래 키로 남는데, `Cmd+\`(0x2A)는 `key_code` 테이블 범위 안이라
  IMK가 이를 `\`로 재해석해 `₩`를 덮어쓴다. IMK 경로가 `SpecialKeyTap.outputs`에
  속한 문자를 만나면 keycode 해석을 건너뛰도록 처리.
  (`~`, `` ` ``는 keycode 0x35로 테이블 범위 밖이라 원래 영향 없음)

### 모디파이어 정확 일치
- 기존 `flags.contains(combo.flag)`는 추가 모디파이어를 허용해, `Cmd+Shift+ESC`가
  테이블 첫 항목(`Shift+ESC`)에 걸려 `~`를 냈다.
- `matchedFlags`(shift/control/option/command)로 걸러낸 뒤 등가 비교로 변경.
  Caps Lock과 fn은 마스크에서 제외 — 켜져 있다고 조합이 깨지면 안 되므로.

### 문서/UI
- 권한이 없으면 특수키가 **어느 입력기에서도** 동작하지 않음을 README, 트레이 메뉴
  주석, 권한 안내 alert에 반영.

## 2026-05-27 - 전역 특수키 입력 및 개인 빌드 서명

### 특수키 조합을 다른 입력기 상태에서도 동작 (전역)
- `SpecialKeyTap`: 세션 레벨 `CGEventTap`으로 특수키 조합(`Shift+ESC→~`,
  `Cmd+ESC→\``, `Cmd+\→₩`)을 전역에서 가로채 치환.
- 현재 입력기가 NavilIME가 아닐 때만 가로채고, NavilIME 활성 시엔 기존 IMK
  경로가 처리하도록 분기 → 이중 처리 방지.
- 탭이 타임아웃/사용자 입력으로 비활성화되면 자동 재활성화.
- App Sandbox에서는 전역 이벤트 탭이 막히므로 entitlements에서 `app-sandbox`를
  끔. (App Store가 아닌 직접 설치 방식이라 무방)

### 손쉬운 사용 권한 UI
- `CGEventTap`은 손쉬운 사용(Accessibility) 권한이 필요.
- 트레이 메뉴에 "특수키 전역 입력 권한 허용…" 항목 추가. 권한이 있으면
  "특수키 전역 입력: 켜짐 ✓"로 표시(비활성).
- 클릭 시 시스템 권한 요청 + 손쉬운 사용 설정 창 열기 + 안내 alert.
  LSBackgroundOnly 환경에서도 표시되도록 활성화 정책을 잠시 올림.
- 부팅 시 권한이 이미 있으면 탭 자동 시작.

### 개인 빌드 서명 구조
- `Signing.xcconfig`(기본 ad-hoc) + `Local.xcconfig.example`(템플릿) 도입.
  실제 `Local.xcconfig`는 `.gitignore`로 커밋 제외 → 개인 Team ID 비공개.
- pbxproj에서 하드코딩된 `DEVELOPMENT_TEAM`/`CODE_SIGN_IDENTITY` 제거,
  `baseConfigurationReference`로 xcconfig 연결.
- `.gitignore` 신설, 추적되던 `.DS_Store` 추적 해제.

## 2026-05-23 - 옵션 창 제거 및 안정성 라운드

### 옵션 창 제거, 한영전환 단축키를 트레이 메뉴로 통합
- 옵션 창과 관련 xib UI 전체 제거
- 한/영 전환 단축키 설정(시스템입력기 사용 / 왼쪽 Shift+Space / 오른쪽 Command / 오른쪽 Option)을 트레이 메뉴 라디오 항목으로 이동

### 두벌식 ㄷㄷㄷ 옵션 제거
- 같은 자음 연속 입력을 쌍자음으로 합치는 옵션 제거
- `shift_cho`(분리 입력) 동작을 영구 기본으로 고정, 관련 테이블/영속화 코드 단순화

### 안정성 개선
- 죽은 NSScrollView 출력을 `os_log` 래퍼로 교체 (Console.app에서 `subsystem=io.navilera.NavilIME`로 필터링)
- `setMarkedText` selectionRange를 grapheme count 대신 NSString.length(UTF-16)로 계산 (NFD 분해된 한글 잘림 방지)
- cmd/option/control이 눌린 keycode는 hotfix 순환버퍼에 넣지 않음 (false-positive 방지)
- 드래그 매 프레임 commit 호출 제거
- IBOutlet들을 옵셔널로 변경, xib에 위젯이 없어도 크래시 없이 진행

## 2026-04-14 - 대규모 정리 및 개선

### 세벌식 제거
- 세벌식 318, 390 키보드 코드 전부 삭제 (`Keyboard318.swift`, `Keyboard390.swift`)
- 두벌식(Keyboard002)만 남김
- Hangul, Keyboards, SingletonMenu, SingletonOpt, Testcases 등에서 관련 참조 모두 제거
- 트레이 메뉴에서 키보드 선택 항목 제거 (옵션 메뉴만 남김)

### 옵션 창 개선
- 디버깅용 scrollView 제거
- 윈도우 크기 축소 (517px -> 210px)
- 타이틀 "NavilIME 옵션"으로 변경
- AppDelegate에서 디버그 로그 설정 코드 제거

### 특수키 조합 추가
- `Shift + ESC` -> `~` (물결)
- `Cmd + ESC` -> `` ` `` (백틱)
- `Cmd + \` -> `₩` (원화 기호)
- 테이블 기반으로 구현되어 있어 `special_keys` 배열에 추가만 하면 확장 가능

### 크래시 방어
- `Hangul!` (force unwrap) -> `Hangul?` (optional)로 변경
- `Automata` 접근 시 `guard let` 패턴 적용
- macOS가 비정상 순서로 생명주기 호출할 때 (화면 잠금, 슬립 복귀, 빠른 앱 전환) 크래시 방지

### Hotfix 버퍼 오염 방지
- 특수키 조합을 Hotfix 패턴 체크 이전에 처리
- ESC 등의 keycode가 hotfix circular buffer에 들어가지 않음
