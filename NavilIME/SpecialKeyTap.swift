//
//  SpecialKeyTap.swift
//  NavilIME
//
//  전역 키 가로채기(CGEventTap)로 특수키 조합을 다른 입력기 상태에서도 치환한다.
//
//  NavilIME가 활성 입력기일 때는 IMK 경로(NavilIMEInputController.special_keys)가
//  이미 처리하므로, 이 탭은 "현재 입력기가 NavilIME가 아닐 때"만 동작시켜 이중 처리를
//  막는다. 동작하려면 App Sandbox가 꺼져 있어야 하고 손쉬운 사용(Accessibility)
//  권한이 허용돼야 한다.
//

import Cocoa
import ApplicationServices
import Carbon

// IMK 경로(NavilIMEInputController.special_keys)와 동일한 조합을 유지한다.
struct SpecialKeyCombo {
    let keyCode: CGKeyCode
    let flag: CGEventFlags
    let output: String
}

class SpecialKeyTap {
    static let shared = SpecialKeyTap()

    // NavilIMEInputController.special_keys와 짝을 이룬다. 한쪽을 바꾸면 다른 쪽도 맞춘다.
    let combos: [SpecialKeyCombo] = [
        SpecialKeyCombo(keyCode: 0x35, flag: .maskShift,   output: "~"),  // Shift+ESC → ~
        SpecialKeyCombo(keyCode: 0x35, flag: .maskCommand, output: "`"),  // Cmd+ESC → `
        SpecialKeyCombo(keyCode: 0x2A, flag: .maskCommand, output: "₩"), // Cmd+\ → ₩
    ]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    var isTrusted: Bool {
        return AXIsProcessTrusted()
    }

    var isRunning: Bool {
        return eventTap != nil
    }

    // 손쉬운 사용 권한이 있으면 탭을 켠다. 권한이 없으면 시스템 권한 요청 다이얼로그를 띄운다.
    func requestPermissionPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // 권한이 있으면(그리고 아직 안 켜졌으면) 탭을 시작한다.
    func startIfTrusted() {
        guard isTrusted, eventTap == nil else { return }
        start()
    }

    func start() {
        guard eventTap == nil else { return }
        guard isTrusted else {
            PrintLog.shared.Log(log: "SpecialKeyTap: not trusted, tap not created")
            return
        }

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
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        PrintLog.shared.Log(log: "SpecialKeyTap: started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
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

        // NavilIME가 활성 입력기면 IMK 경로가 처리하므로 건드리지 않는다.
        if currentInputSourceIsNavil() {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        for combo in combos where keyCode == combo.keyCode && flags.contains(combo.flag) {
            event.flags = CGEventFlags(rawValue: 0)
            let utf16 = Array(combo.output.utf16)
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func currentInputSourceIsNavil() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyBundleID) else {
            return false
        }
        let bundleID = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        return bundleID == (Bundle.main.bundleIdentifier ?? "")
    }
}
