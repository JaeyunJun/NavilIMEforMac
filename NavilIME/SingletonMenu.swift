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
    var self_eng_mode:Bool = false

    // 트레이 메뉴에 노출되는 한영전환 단축키 항목들.
    // tag는 OptHandler.Is_han_eng_changed가 해석하는 hotkey_radio_tag와 동일.
    let hotkey_items:[NSMenuItem]

    // 특수키(₩, ~, `) 입력 권한 상태/허용 항목. menu()가 그릴 때마다 갱신한다.
    // 이 권한이 없으면 특수키 조합은 한글/영문 어느 쪽에서도 동작하지 않는다.
    let permission_item:NSMenuItem

    private init() {
        self.menu = NSMenu()

        let titles:[(Int, String)] = [
            (0, "시스템입력기 사용"),
            (1, "왼쪽 Shift + Space"),
            (2, "오른쪽 Command"),
            (3, "오른쪽 Option"),
        ]

        let header = NSMenuItem()
        header.title = "한/영 전환"
        header.isEnabled = false
        self.menu.addItem(header)

        var items:[NSMenuItem] = []
        let current_tag = OptHandler.shared.hotkey_radio_tag
        for (tag, title) in titles {
            let it = NSMenuItem()
            it.title = title
            it.tag = tag
            it.state = (tag == current_tag) ? .on : .off
            it.action = #selector(NavilIMEInputController.select_haneng_hotkey(_:))
            it.isEnabled = true
            self.menu.addItem(it)
            items.append(it)
        }

        self.hotkey_items = items

        self.menu.addItem(NSMenuItem.separator())
        let perm = NSMenuItem()
        perm.action = #selector(NavilIMEInputController.grant_special_key_permission(_:))
        self.permission_item = perm
        self.menu.addItem(perm)

        self.menu.autoenablesItems = true
        self.refresh_permission_state()
    }

    func set_hotkey(tag:Int) {
        OptHandler.shared.HanEng_hotkey(sel: tag)
        for it in self.hotkey_items {
            it.state = (it.tag == tag) ? .on : .off
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
