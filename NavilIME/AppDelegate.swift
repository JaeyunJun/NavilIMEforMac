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

    var server = IMKServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("tried connection")

        // 손쉬운 사용 권한이 이미 있으면 전역 특수키 탭을 켠다.
        // 권한이 없으면 트레이 메뉴의 "특수키 전역 입력 권한 허용…"에서 직접 허용한다.
        SpecialKeyTap.shared.startIfTrusted()

        // 터미널 암호 프롬프트(sudo/ssh/git 등) 감시 시작.
        // 권한이 필요 없고, tty의 termios만 읽는다.
        TTYPasswordWatcher.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 우리가 쥔 secure input을 반드시 되돌린다.
        TTYPasswordWatcher.shared.stop()
    }
}
