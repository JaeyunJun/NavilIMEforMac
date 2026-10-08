//
//  InputSource.swift
//  NavilIME
//
//  시스템 입력 소스 조회와 끊긴 입력 세션 복구.
//
//  [끊긴 세션] 메뉴 막대는 NavilIME인데 키가 입력기를 거치지 않고 앱으로 바로 가서 영문이
//  나오는 상태. 실측: Raycast를 Option+Space로 닫고 Orca로 돌아오면 macOS가 Orca 입력창에
//  입력기를 켰다가 1ms 만에 끄고, 다시 켜지 않았다. 입력기는 키를 받지 못하므로 스스로
//  알 수 없고, 전역 탭(SpecialKeyTap)이 "입력기가 선택됐는데 켜진 입력창이 없는 상태에서
//  글자 키가 눌림"으로 알아챈다. 그때 입력 소스를 ABC로 갔다가 NavilIME로 되돌려 macOS가
//  입력창에 입력기를 다시 붙이게 한다.
//
//  입력창이 없는 화면(바탕화면, 게임 등)에서도 같은 조건이 되므로, 입력기가 꺼질 때마다
//  한 번만 시도한다. 계속 전환되며 깜빡이지 않게 하기 위해서다.
//

import Carbon
import Foundation

enum InputSource {
    // 시스템의 현재 입력 소스가 NavilIME인가. 다른 프로세스가 바꿔도 바로 반영된다.
    static func isNavilSelected() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        return id(of: source) == Bundle.main.bundleIdentifier
    }

    // 메인 스레드에서만 만진다.
    private static var recoveryArmed = false
    private static var deactivatedAt: TimeInterval = 0

    // 앱이 입력창을 다시 만들 때(예: Orca에서 Enter) 입력기가 꺼졌다 약 100ms 뒤 다시 켜진다(실측).
    // 그 사이의 키는 끊긴 게 아니므로, 꺼진 뒤 이만큼 지나도 안 켜졌을 때만 끊긴 것으로 본다.
    private static let detachGrace: TimeInterval = 0.3

    // 입력기가 꺼질 때 부른다. 이후 글자 키에서 한 번 확인한다.
    static func armRecovery() {
        recoveryArmed = true
        deactivatedAt = ProcessInfo.processInfo.systemUptime
    }

    // 입력기가 켜지면 끊긴 게 아니다.
    static func disarmRecovery() {
        recoveryArmed = false
    }

    // 탭이 "켜진 입력창 없이 글자 키가 눌림"을 알릴 때 메인 스레드에서 부른다.
    static func keyPressedWithoutSession() {
        guard recoveryArmed,
              ProcessInfo.processInfo.systemUptime - deactivatedAt > detachGrace else { return }
        recoveryArmed = false
        // ABC 등 다른 입력 소스면 입력기가 꺼진 게 정상이다.
        guard isNavilSelected(), let navil = navilSource(), let ascii = asciiLayoutSource() else { return }

        Log.debug("Session detached while NavilIME selected, reattaching")
        TISSelectInputSource(ascii)
        // 같은 순간에 되돌리면 전환이 합쳐져 아무 일도 안 일어날 수 있어 잠깐 띄운다.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            TISSelectInputSource(navil)
        }
    }

    private static func id(of source: TISInputSource) -> String? {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }

    private static func enabledKeyboardSources(asciiOnly: Bool) -> [TISInputSource] {
        var filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true,
            kTISPropertyInputSourceIsEnabled as String: true,
        ]
        if asciiOnly {
            filter[kTISPropertyInputSourceIsASCIICapable as String] = true
        }
        return TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue()
            as? [TISInputSource] ?? []
    }

    private static func navilSource() -> TISInputSource? {
        return enabledKeyboardSources(asciiOnly: false).first { id(of: $0) == Bundle.main.bundleIdentifier }
    }

    // ASCII 가능한 '키보드 레이아웃'만 고른다. 입력 모드까지 포함하면 다른 언어 입력기가
    // 걸릴 수 있다. 보통 ABC가 잡힌다.
    private static func asciiLayoutSource() -> TISInputSource? {
        return enabledKeyboardSources(asciiOnly: true).first { source in
            guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else { return false }
            return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String == kTISTypeKeyboardLayout as String
        }
    }
}
