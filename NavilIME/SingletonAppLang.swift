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

    // 마지막으로 지정값을 적용한 앱. 같은 앱 안에서 사용자가 ⌘Space로 직접 바꾼 것을
    // 되돌리지 않기 위해, '앱이 바뀔 때'만 적용한다. (전환 루프도 이걸로 막힌다.)
    private var last_applied:String?

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
        guard last_applied != bundle_id else { return }
        last_applied = bundle_id

        switch lang(for: bundle_id) {
        case .unset:
            return
        case .hangul:
            if Self.current_is_navil() == false {
                Self.select(Self.navil_source())
            }
        case .english:
            // 입력 소스를 바꾸지 않는다. 런처 오버레이(Raycast 등)는 최전면 앱을 바꾸지 않고
            // 키 포커스만 빌려 쓰는 '비활성화 패널'인데, 그 상태에서 TISSelectInputSource 를
            // 부르면 IMK 세션이 갈리면서 빌린 포커스가 소유 앱으로 돌아가버린다.
            // (호출을 다음 런루프로 미뤄도 동일하다. 타이밍이 아니라 호출 자체가 원인이다.)
            //
            // 대신 이 앱에서는 조합만 멈춘다 — NavilIMEInputController 의 키 입력 경로가
            // lang(for:) 을 보고 판단한다. 키가 들어온 시점에 동기로 판정하므로 전환을
            // 기다리다 첫 글자가 한글로 들어가는 경쟁도 없다.
            break
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
        // activateServer 안에서 곧바로 입력 소스를 바꾸면, IMK 가 새 클라이언트로 입력기를
        // 활성화하는 도중에 세션이 갈려 포커스가 튄다(런처 오버레이에서 첫 글자가 들어간 뒤
        // 입력이 끊기는 증상). 다음 런루프로 미뤄 활성화가 끝난 뒤에 바꾼다.
        DispatchQueue.main.async {
            TISSelectInputSource(source)
        }
    }

    private static func enabled_sources() -> [TISInputSource] {
        let filter:[String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true,
            kTISPropertyInputSourceIsEnabled as String: true,
        ]
        return TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue()
            as? [TISInputSource] ?? []
    }

    private static func navil_source() -> TISInputSource? {
        let me = Bundle.main.bundleIdentifier ?? ""
        return enabled_sources().first { source_id($0) == me }
    }

    /// 트레이 메뉴에 보여줄 짧은 이름. "com.apple.Terminal" → "Terminal"
    static func short_name(_ bundle_id: String) -> String {
        return bundle_id.components(separatedBy: ".").last ?? bundle_id
    }
}
