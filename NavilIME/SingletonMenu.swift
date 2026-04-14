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

    private init() {
        self.menu = NSMenu()

        let option_menuitem = NSMenuItem()
        option_menuitem.title = "옵션"
        option_menuitem.tag = OptHandler.shared.opt_menu_tag
        option_menuitem.action = #selector(NavilIMEInputController.select_menu(_:))
        option_menuitem.isEnabled = true
        self.menu.addItem(option_menuitem)

        self.menu.autoenablesItems = true
    }
}
