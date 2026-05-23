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
        self.menu.autoenablesItems = true
    }

    func set_hotkey(tag:Int) {
        OptHandler.shared.HanEng_hotkey(sel: tag)
        for it in self.hotkey_items {
            it.state = (it.tag == tag) ? .on : .off
        }
    }
}
