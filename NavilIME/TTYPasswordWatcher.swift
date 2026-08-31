//
//  TTYPasswordWatcher.swift
//  NavilIME
//
//  터미널의 암호 프롬프트를 감지해, 그동안 입력기가 조합을 멈추게 한다.
//
//  왜 필요한가: macOS는 암호 필드(잠금 화면, 키체인 등)에서 secure input을 켜주지만,
//  터미널의 sudo/ssh/git 프롬프트에서는 켜주지 않는다. 터미널 앱이 pty의 상태를
//  보지 않기 때문이다. 그래서 한글 상태로 비밀번호를 치면 한글이 들어간다.
//
//  판별법: 비밀번호를 읽는 프로그램은 tty를 "정규 모드(ICANON) + 에코 끔(ECHO off)"
//  으로 만든다. vim·top 같은 전체화면 TUI는 raw 모드(ICANON off)라 구분된다.
//  실측으로 확인했다:
//
//      cat      정규 + 에코 on    → 평범한 입력
//      getpass  정규 + 에코 OFF   → 암호 프롬프트   ← 이것만 잡는다
//      vi       raw  + 에코 OFF   → TUI (오탐 아님)
//      top      raw  + 에코 OFF   → TUI (오탐 아님)
//
//  덕분에 sudo뿐 아니라 ssh, git 자격증명, passwd, su, python getpass 등
//  "에코를 끄고 비밀번호를 읽는 모든 것"이 한 번에 커버된다.
//
//  감지하면 EnableSecureEventInput()을 켠다. 조합을 멈추는 것은 물론, 그동안
//  다른 앱의 이벤트 탭까지 차단되어 실제 키로거 방어가 된다.
//
//  [스레딩] 타이머도 조회도 전부 메인 큐에서 돈다. IMK 입력 경로가 메인 스레드이므로
//  락 없이 안전하다.
//
//  [비용] 실측 1회 스캔 약 515µs. 대부분이 tty를 open 하는 비용이라(하나당 ~57µs)
//  디렉터리 목록을 캐시해도 줄지 않는다. 그래서:
//    - 타이머는 1초 주기 (약 0.05% CPU). 프롬프트가 뜨자마자 secure input을 켜는 용도.
//    - 키 입력 경로는 100ms TTL 캐시로 확인. 빠르게 타이핑해도 10키당 1회 스캔이라
//      키당 평균 50µs 수준이고, 프롬프트 직후 첫 글자도 놓치지 않는다.
//

import Cocoa
import Carbon

final class TTYPasswordWatcher {
    static let shared = TTYPasswordWatcher()

    // 프롬프트가 떠 있는 동안 secure input을 우리가 쥐고 있는지.
    // Enable/Disable은 프로세스별 참조 카운트라, 우리가 켠 만큼만 꺼야 한다.
    private var holdingSecureInput = false

    private var timer: DispatchSourceTimer?

    // 키 입력 경로에서 매번 tty를 훑지 않도록 짧게 캐시한다.
    private var cachedActive = false
    private var cachedAt = DispatchTime.now()
    private static let cacheTTL: UInt64 = 100_000_000   // 100ms

    // 프롬프트가 뜨자마자(타이핑 전에) secure input을 켜기 위한 주기.
    // 조합 차단 자체는 키 입력 경로가 즉시 처리하므로, 이 타이머는 느려도 된다.
    private static let pollInterval: DispatchTimeInterval = .seconds(1)

    private init() {}

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: Self.pollInterval)
        t.setEventHandler { [weak self] in self?.refresh() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        setSecureInput(false)
    }

    /// 키 입력 경로에서 부르는 동기 확인. 캐시가 오래됐으면 즉시 다시 훑는다.
    /// (타이머 주기를 기다리면 프롬프트 직후 첫 글자를 놓칠 수 있다.)
    func isPasswordPromptActive() -> Bool {
        let elapsed = DispatchTime.now().uptimeNanoseconds &- cachedAt.uptimeNanoseconds
        if elapsed < Self.cacheTTL {
            return cachedActive
        }
        return refresh()
    }

    @discardableResult
    private func refresh() -> Bool {
        let active = Self.anyTTYAwaitingPassword()
        cachedActive = active
        cachedAt = DispatchTime.now()
        setSecureInput(active)
        return active
    }

    private func setSecureInput(_ on: Bool) {
        if on && !holdingSecureInput {
            if EnableSecureEventInput() == noErr {
                holdingSecureInput = true
            }
        } else if !on && holdingSecureInput {
            DisableSecureEventInput()
            holdingSecureInput = false
        }
    }

    /// 사용자 소유 tty 중 "정규 모드 + 에코 꺼짐"인 것이 하나라도 있는가.
    private static func anyTTYAwaitingPassword() -> Bool {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: "/dev") else {
            return false
        }
        let uid = getuid()
        for name in entries where name.hasPrefix("ttys") {
            let path = "/dev/" + name
            var info = stat()
            guard stat(path, &info) == 0, info.st_uid == uid else { continue }

            // O_NOCTTY: 이 tty가 우리 controlling terminal이 되지 않게 한다.
            // O_NONBLOCK: 열기만 하고 절대 블록되지 않게 한다.
            let fd = open(path, O_RDONLY | O_NONBLOCK | O_NOCTTY)
            guard fd >= 0 else { continue }
            defer { close(fd) }

            var term = termios()
            guard tcgetattr(fd, &term) == 0 else { continue }
            let canonical = (term.c_lflag & tcflag_t(ICANON)) != 0
            let echoing = (term.c_lflag & tcflag_t(ECHO)) != 0
            if canonical && !echoing {
                return true
            }
        }
        return false
    }
}
