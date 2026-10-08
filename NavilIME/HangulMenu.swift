//
//  HangulMenu.swift
//  NavilIME
//
//  메뉴 막대 입력기 메뉴. IMK가 menu()로 가져가 그린다.
//

import Cocoa

final class HangulMenu {
    static let shared = HangulMenu()

    let menu = NSMenu()

    // 앱별 한/영 고정. 어느 앱인지는 menu()에 안 넘어오므로 마지막 클라이언트를 쓴다.
    // tag는 AppLang.rawValue와 같다.
    private let appLangHeader = NSMenuItem()
    private let appLangItems: [NSMenuItem]

    // 특수키(₩, ~, `) 권한 상태. 누르면 권한 상태 창이 열린다.
    // 이 권한이 없으면 특수키 조합은 한글/영문 어느 쪽에서도 동작하지 않는다.
    private let permissionItem = NSMenuItem()

    private init() {
        appLangHeader.isEnabled = false
        menu.addItem(appLangHeader)

        appLangItems = [AppLang.unset, .hangul, .english].map { lang in
            let item = NSMenuItem()
            item.title = lang.title
            item.tag = lang.rawValue
            item.action = #selector(NavilIMEInputController.selectAppLang(_:))
            return item
        }
        appLangItems.forEach(menu.addItem)

        menu.addItem(.separator())
        permissionItem.action = #selector(NavilIMEInputController.showPermissionWindow(_:))
        menu.addItem(permissionItem)

        menu.autoenablesItems = true
        refreshPermissionState()
        refreshAppLangState()
    }

    // 지금 입력 중인 앱의 고정 설정을 메뉴에 반영한다. menu()가 그릴 때마다 불린다.
    func refreshAppLangState() {
        guard let bundleID = NavilIMEInputController.lastClientBundleID else {
            appLangHeader.title = "이 앱에서 항상 (앱 확인 불가)"
            for item in appLangItems {
                item.isEnabled = false
                item.state = .off
            }
            return
        }
        appLangHeader.title = "‘\(AppLangHandler.shortName(bundleID))’에서 항상"
        let current = AppLangHandler.shared.lang(for: bundleID)
        for item in appLangItems {
            item.isEnabled = true
            item.state = (item.tag == current.rawValue) ? .on : .off
        }
    }

    // 실제 권한과 탭 상태를 제목에 보여준다. 어느 상태든 누르면 권한 상태 창이 열린다.
    func refreshPermissionState() {
        let tap = SpecialKeyTap.shared
        if !tap.isTrusted {
            permissionItem.title = "특수키 전역 입력: 권한 없음 ❌ — 허용하기…"
        } else if !tap.isActive {
            permissionItem.title = "특수키 전역 입력: 권한 있음, 탭 꺼짐 ⚠️…"
        } else {
            permissionItem.title = "특수키 전역 입력: 켜짐 ✓…"
        }
        permissionItem.isEnabled = true
    }
}
