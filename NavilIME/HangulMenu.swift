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

    // 특수키(₩, ~, `) 권한 상태. 누르면 권한 상태 창이 열린다.
    // 이 권한이 없으면 특수키 조합은 한글/영문 어느 쪽에서도 동작하지 않는다.
    private let permissionItem = NSMenuItem()

    private init() {
        permissionItem.action = #selector(NavilIMEInputController.showPermissionWindow(_:))
        menu.addItem(permissionItem)
        menu.autoenablesItems = true
        refreshPermissionState()
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
