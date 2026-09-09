//
//  SingletonAppLang.swift
//  NavilIME
//
//  앱별 한/영 고정 설정. 지정한 앱에 들어갈 때만 모드를 강제한다.
//
//  한/영은 macOS 입력 소스 선택으로 결정된다 (한글 = NavilIME, 영문 = ABC 등 ASCII
//  레이아웃). 지정한 앱이 앞으로 나오면 해당 입력 소스를 선택해 준다.
//
//  기본값은 '지정 안 함'이다. 지정하지 않은 앱은 지금까지와 똑같이 동작한다 —
//  모든 앱을 자동으로 기억하면 앱을 바꿀 때마다 언어가 바뀌어 예측이 어려워진다.
//

import Foundation
import Carbon
import Cocoa

enum AppLang: Int {
    case unset = 0      // 지정 안 함 — 현재 상태를 그대로 둔다
    case hangul = 1
    case english = 2

    var title: String {
        switch self {
        case .unset:   return "지정 안 함"
        case .hangul:  return "한글"
        case .english: return "영문"
        }
    }
}

class AppLangHandler {
    static let shared = AppLangHandler()

    private let db_key = "app_lang_map"
    // 지정한 앱만 담는다. 지정 안 한 앱은 키 자체가 없다.
    private var map: [String: Int]

    private init() {
        map = UserDefaults.standard.dictionary(forKey: db_key) as? [String: Int] ?? [:]
    }

    func lang(for bundle_id: String) -> AppLang {
        return AppLang(rawValue: map[bundle_id] ?? 0) ?? .unset
    }

    func set(_ lang: AppLang, for bundle_id: String) {
        if lang == .unset {
            map.removeValue(forKey: bundle_id)
        } else {
            map[bundle_id] = lang.rawValue
        }
        UserDefaults.standard.set(map, forKey: db_key)
    }

    /// 앱이 앞으로 나올 때 지정값을 적용한다.
    ///
    /// activateServer는 NavilIME가 '선택된 입력기'일 때만 불린다. 입력 소스가 ABC면
    /// NavilIME는 콜백을 못 받으므로, 앱 전환 자체를 감시해서 여기서 처리해야 한다.
    /// (프로세스는 입력 소스와 무관하게 계속 살아있다.)
    ///
    ///   한글 지정 + 현재 ABC      → NavilIME로 전환하고 한글
    ///   한글 지정 + 현재 NavilIME → 한글
    ///   영문 지정 + 현재 ABC      → 그대로 둔다. 이미 영문이고, 사용자가 고른
    ///                              입력 소스를 뒤엎을 이유가 없다
    ///   영문 지정 + 현재 NavilIME → 영문
    func apply_on_activate(bundle_id:String) {
        switch lang(for: bundle_id) {
        case .unset:
            return
        case .hangul:
            if Self.current_is_navil() == false {
                Self.select(Self.navil_source())
            }
        case .english:
            if Self.current_is_navil() {
                Self.select(Self.ascii_layout_source())
            }
        }
    }

    private static func source_id(_ source:TISInputSource) -> String? {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }

    private static func current_is_navil() -> Bool {
        guard let s = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id = source_id(s) else { return false }
        return id == (Bundle.main.bundleIdentifier ?? "")
    }

    private static func select(_ source:TISInputSource?) {
        guard let source = source else { return }
        TISSelectInputSource(source)
    }

    private static func enabled_sources(ascii_only:Bool) -> [TISInputSource] {
        var filter:[String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true,
            kTISPropertyInputSourceIsEnabled as String: true,
        ]
        if ascii_only {
            filter[kTISPropertyInputSourceIsASCIICapable as String] = true
        }
        return TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue()
            as? [TISInputSource] ?? []
    }

    private static func navil_source() -> TISInputSource? {
        let me = Bundle.main.bundleIdentifier ?? ""
        return enabled_sources(ascii_only: false).first { source_id($0) == me }
    }

    /// 영문용. ASCII 가능한 '키보드 레이아웃'만 고른다 — 입력 모드까지 포함하면
    /// 다른 언어 입력기가 걸릴 수 있다. 보통 ABC가 잡힌다.
    private static func ascii_layout_source() -> TISInputSource? {
        return enabled_sources(ascii_only: true).first { source in
            guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else { return false }
            let type = Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
            return type == (kTISTypeKeyboardLayout as String)
        }
    }

    /// 트레이 메뉴에 보여줄 짧은 이름. "com.apple.Terminal" → "Terminal"
    static func short_name(_ bundle_id: String) -> String {
        return bundle_id.components(separatedBy: ".").last ?? bundle_id
    }
}
