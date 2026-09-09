//
//  SingletonMenu.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/29/22.
//

import Foundation
import Cocoa

class HangulMenu {
    static let shared = HangulMenu()

    var menu:NSMenu

    // 특수키(₩, ~, `) 입력 권한 상태/허용 항목. menu()가 그릴 때마다 갱신한다.
    // 이 권한이 없으면 특수키 조합은 한글/영문 어느 쪽에서도 동작하지 않는다.
    let permission_item:NSMenuItem

    // 앱별 한/영 고정. 어느 앱인지는 menu()에 안 넘어오므로 마지막 클라이언트를 쓴다.
    // tag는 AppLang.rawValue와 같다.
    let applang_header:NSMenuItem
    let applang_items:[NSMenuItem]

    private init() {
        self.menu = NSMenu()

        let applang_head = NSMenuItem()
        applang_head.isEnabled = false
        self.applang_header = applang_head
        self.menu.addItem(applang_head)

        var lang_items:[NSMenuItem] = []
        for lang in [AppLang.unset, .hangul, .english] {
            let it = NSMenuItem()
            it.title = lang.title
            it.tag = lang.rawValue
            it.action = #selector(NavilIMEInputController.select_app_lang(_:))
            self.menu.addItem(it)
            lang_items.append(it)
        }
        self.applang_items = lang_items

        self.menu.addItem(NSMenuItem.separator())
        let perm = NSMenuItem()
        perm.action = #selector(NavilIMEInputController.grant_special_key_permission(_:))
        self.permission_item = perm
        self.menu.addItem(perm)

        self.menu.autoenablesItems = true
        self.refresh_permission_state()
        self.refresh_app_lang_state()
    }

    // 지금 입력 중인 앱의 고정 설정을 메뉴에 반영한다. menu()가 그릴 때마다 호출된다.
    func refresh_app_lang_state() {
        guard let bundle_id = NavilIMEInputController.last_client_bundle_id else {
            applang_header.title = "이 앱에서 항상 (앱 확인 불가)"
            for it in applang_items {
                it.isEnabled = false
                it.state = .off
            }
            return
        }
        applang_header.title = "‘\(AppLangHandler.short_name(bundle_id))’에서 항상"
        let current = AppLangHandler.shared.lang(for: bundle_id)
        for it in applang_items {
            it.isEnabled = true
            it.state = (it.tag == current.rawValue) ? .on : .off
        }
    }

    // 권한이 있으면 안내 문구만 보여주고(비활성), 없으면 허용 동작을 노출한다.
    func refresh_permission_state() {
        if SpecialKeyTap.shared.isTrusted {
            permission_item.title = "특수키 전역 입력: 켜짐 ✓"
            permission_item.isEnabled = false
        } else {
            permission_item.title = "특수키 전역 입력 권한 허용…"
            permission_item.isEnabled = true
        }
    }
}
