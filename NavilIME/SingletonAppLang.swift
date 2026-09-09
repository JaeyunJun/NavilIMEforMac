//
//  SingletonAppLang.swift
//  NavilIME
//
//  앱별 한/영 고정 설정. 지정한 앱에 들어갈 때만 모드를 강제한다.
//
//  왜 입력기가 직접 하는가: 이 입력기의 한/영은 입력 소스를 바꾸는 게 아니라
//  self_eng_mode 라는 내부 플래그 하나를 뒤집는 방식이다. macOS 입장에선 어느 앱에서든
//  "NavilIME 선택됨"으로 똑같이 보이므로, OS의 "문서의 입력 소스로 자동 전환" 기능이
//  이 상태를 기억해줄 수 없다. 내부 상태는 입력기만 아니까 입력기가 기억해야 한다.
//
//  기본값은 '지정 안 함'이다. 지정하지 않은 앱은 지금까지와 똑같이 동작한다 —
//  모든 앱을 자동으로 기억하면 앱을 바꿀 때마다 언어가 바뀌어 예측이 어려워진다.
//

import Foundation

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

    /// 트레이 메뉴에 보여줄 짧은 이름. "com.apple.Terminal" → "Terminal"
    static func short_name(_ bundle_id: String) -> String {
        return bundle_id.components(separatedBy: ".").last ?? bundle_id
    }
}
