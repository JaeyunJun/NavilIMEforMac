# NavilIME 개인 수정 기록

이 프로젝트는 **Manwoo Yi**([@navilera](https://github.com/navilera))님이 만든 macOS용 한글 입력기입니다.
세벌식 318Na 자판을 직접 디자인하고, 리눅스/윈도우/맥 전부 입력기를 직접 구현하신 분입니다.
아래는 개인 용도로 포크하여 수정한 내용입니다.

원본: [navilera/NavilIMEforMac](https://github.com/navilera/NavilIMEforMac)

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
