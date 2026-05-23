//
//  SingletonOpt.swift
//  NavilIME
//
//  Created by Manwoo Yi on 3/31/23.
//
//  한영전환 단축키 상태와 영속화만 담당. UI는 트레이 메뉴(HangulMenu)가 책임진다.
//

import Foundation
import Cocoa

class OptHandler {
    static let shared = OptHandler()

    let hotkeys_db_key = "han_eng_hotkey_opt"
    var hotkey_radio_tag = 0

    private init() {
        hotkey_radio_tag = UserDefaults.standard.integer(forKey: hotkeys_db_key)
    }

    func HanEng_hotkey(sel:Int) {
        hotkey_radio_tag = sel
        UserDefaults.standard.set(hotkey_radio_tag, forKey: hotkeys_db_key)
    }

    func Is_han_eng_changed(keycode:uint16, modi:NSEvent.ModifierFlags) -> Bool {
        /*
         오른쪽 cmd = 54 — keycode=54 modi=1048576
         오른쪽 옵션 = 61 — keycode=61 modi=524288
         스페이스 시프트 — keycode=56 modi=131072
         keycode = 49 cmd = false opt = false shift = true
         */
        PrintLog.shared.Log(log: "keycode = \(keycode) cmd = \(modi.contains(.command)) opt = \(modi.contains(.option)) shift = \(modi.contains(.shift))")

        // nothing
        if hotkey_radio_tag == 0 {
            return false
        }
        // shift + space
        if hotkey_radio_tag == 1 {
            if keycode == 49 && modi.contains(.shift) {
                return true
            }
        }
        // right cmd
        if hotkey_radio_tag == 2 {
            if keycode == 54 && modi.contains(.command) {
                return true
            }
        }
        // right opt
        if hotkey_radio_tag == 3 {
            if keycode == 61 && modi.contains(.option) {
                return true
            }
        }
        return false
    }
}
