//
//  SpecialKeyTap.swift
//  NavilIME
//
//  전역 키 가로채기(CGEventTap)로 특수키 조합을 모든 입력기 상태에서 치환한다.
//
//  이 탭이 특수키 조합의 유일한 처리 경로다. IMK 경로(IMKInputController.handle)는
//  ⌘ 조합을 아예 받지 못한다 — ⌘ 이벤트는 AppKit의 키 이퀴벌런트 단계에서 소비되어
//  입력기까지 내려오지 않기 때문이다. 반면 이 탭은 세션 레벨(headInsertEventTap)이라
//  AppKit보다 먼저 이벤트를 보고, 모디파이어를 지운 뒤 유니코드를 갈아끼울 수 있다.
//  그래서 NavilIME가 활성이든(한글) 아니든(영문) 이 탭이 처리한다.
//  치환된 이벤트는 모디파이어 없는 평범한 키가 되지만 keycode는 원래 키 그대로다.
//  그래서 IMK 경로는 keycode 대신 event.characters를 봐야 한다 — 아래 outputs 참조.
//
//  동작하려면 App Sandbox가 꺼져 있어야 하고 손쉬운 사용(Accessibility) 권한이
//  허용돼야 한다. 권한이 없으면 특수키 조합은 어느 입력기에서도 동작하지 않는다.
//
//  [중요] 탭은 전용 스레드의 런루프에서 돈다. IMK 입력 경로(NavilIMEInputController.handle)는
//  메인 스레드에서 도는데, 시스템 전역 keyDown 탭을 메인 런루프에 걸면 모든 키 입력이
//  메인 스레드를 동기 통과하게 되어, 메인 스레드가 바쁜 순간 입력/전환 지연이 생긴다.
//  그래서 탭은 메인이 아닌 별도 스레드로 분리한다.
//

import Cocoa
import ApplicationServices

// 특수키 조합 테이블의 단일 정의. (IMK 경로에는 사본을 두지 않는다.)
struct SpecialKeyCombo {
    let keyCode: CGKeyCode
    let flag: CGEventFlags
    let output: String
}

class SpecialKeyTap {
    static let shared = SpecialKeyTap()

    // 조합 매칭에 쓰는 모디파이어. 이 마스크로 걸러낸 뒤 '정확히 일치'를 요구하므로
    // Cmd+Shift+ESC 같은 확장 조합은 매칭되지 않는다. Caps Lock(maskAlphaShift)과
    // fn(maskSecondaryFn)은 일부러 뺐다 — 켜져 있다고 조합이 깨지면 안 되기 때문.
    static let matchedFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    static let combos: [SpecialKeyCombo] = [
        SpecialKeyCombo(keyCode: 0x35, flag: .maskShift,   output: "~"),  // Shift+ESC → ~
        SpecialKeyCombo(keyCode: 0x35, flag: .maskCommand, output: "`"),  // Cmd+ESC → `
        SpecialKeyCombo(keyCode: 0x2A, flag: .maskCommand, output: "₩"), // Cmd+\ → ₩
    ]

    // 탭이 이벤트에 심어 넣는 출력 문자들. IMK 경로가 "이 문자는 keycode가 아니라
    // event.characters가 진실"임을 판별하는 데 쓴다. (NavilIMEInputController 참조)
    static let outputs: Set<String> = Set(combos.map { $0.output })

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // 탭은 메인이 아닌 전용 스레드의 런루프에서 돈다.
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?

    private init() {}

    var isTrusted: Bool {
        return AXIsProcessTrusted()
    }

    var isRunning: Bool {
        return tapThread != nil
    }

    // 손쉬운 사용 권한이 있으면 탭을 켠다. 권한이 없으면 시스템 권한 요청 다이얼로그를 띄운다.
    func requestPermissionPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // 권한이 있으면(그리고 아직 안 켜졌으면) 탭을 시작한다.
    func startIfTrusted() {
        guard isTrusted, tapThread == nil else { return }
        start()
    }

    func start() {
        guard tapThread == nil else { return }
        guard isTrusted else {
            PrintLog.shared.Log(log: "SpecialKeyTap: not trusted, tap not created")
            return
        }

        // 전용 스레드의 런루프에서 탭을 돌려 메인 스레드(IMK 입력 경로)와 분리한다.
        let thread = Thread { [weak self] in
            guard let self = self else { return }
            guard self.createTap() else { return }
            self.tapRunLoop = CFRunLoopGetCurrent()
            PrintLog.shared.Log(log: "SpecialKeyTap: started (dedicated thread)")
            CFRunLoopRun()
            self.teardownTap()
            PrintLog.shared.Log(log: "SpecialKeyTap: stopped")
        }
        thread.name = "io.navilera.NavilIME.SpecialKeyTap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = tapRunLoop {
            CFRunLoopStop(rl)
        }
        tapThread = nil
        tapRunLoop = nil
    }

    // 탭 스레드에서 실행. 런루프 소스를 현재(전용) 런루프에 단다.
    private func createTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<SpecialKeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            PrintLog.shared.Log(log: "SpecialKeyTap: tapCreate failed")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    // 탭 스레드에서 실행. 런루프가 멈춘 뒤 정리한다.
    private func teardownTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS가 과도한 부하/사용자 입력으로 탭을 끄면 다시 켠다.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // 조합에 정확히 일치하지 않으면(거의 모든 키) 손대지 않고 즉시 통과한다.
        let matched = flags.intersection(Self.matchedFlags)
        guard let combo = Self.combos.first(where: { keyCode == $0.keyCode && matched == $0.flag }) else {
            return Unmanaged.passUnretained(event)
        }

        // 모디파이어를 지우고 문자를 갈아끼운다. 이게 IMK 경로가 못 하는 일이고,
        // 그래서 한글/영문 어느 쪽이든 여기서 끝낸다.
        event.flags = CGEventFlags(rawValue: 0)
        let utf16 = Array(combo.output.utf16)
        event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        return Unmanaged.passUnretained(event)
    }
}
