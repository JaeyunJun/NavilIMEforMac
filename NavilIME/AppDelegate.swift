//
//  AppDelegate.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/3/22.
//

import Cocoa
import InputMethodKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // 한영전환 - 시스템 입력기 사용
    @IBOutlet weak var nothing_radio: NSButton?
    // 한영전환 - shift + space
    @IBOutlet weak var shift_space_radio: NSButton?
    // 한영전환 - 오른쪽 cmd
    @IBOutlet weak var right_cmd: NSButton?
    // 한영전환 - 오른쪽 opt
    @IBOutlet weak var right_opt: NSButton?

    var server = IMKServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("tried connection")

        // 재부팅 후 나오는 윈도우를 바로 끔
        if let w = NSApplication.shared.windows.first {
            w.close()
        }

        // 옵션 윈도우 - 한영전환 옵션 연결 (xib에서 위젯이 빠져있어도 크래시 없이 진행)
        OptHandler.shared.hotkeys = [self.nothing_radio, self.shift_space_radio, self.right_cmd, self.right_opt].compactMap { $0 }
    }

    func applicationWillTerminate(_ notification: Notification) {
    }

    @IBAction func opt_set_hotkey(_ sender: NSButton) {
        let radio_tag = sender.tag
        OptHandler.shared.HanEng_hotkey(sel: radio_tag)
    }
}
