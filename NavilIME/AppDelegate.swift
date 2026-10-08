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

    // IMK가 입력 세션을 연결하는 서버. 앱이 사는 동안 붙잡고 있어야 한다.
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
                           bundleIdentifier: Bundle.main.bundleIdentifier)

        // 손쉬운 사용 권한이 이미 있으면 전역 특수키 탭을 켠다.
        // 권한이 없으면 입력기 메뉴의 권한 상태 창에서 허용한다.
        SpecialKeyTap.shared.startIfTrusted()

        // 터미널 암호 프롬프트(sudo/ssh/git 등) 감시 시작.
        // 권한이 필요 없고, tty의 termios만 읽는다.
        TTYPasswordWatcher.shared.start()

        // 앱 전환 감시. 입력 소스가 ABC면 activateServer가 안 오므로, 앱별 한/영 지정을
        // 적용하려면 여기서 받아야 한다. 권한 불필요.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            AppLangHandler.shared.applyOnActivate(bundleID: bundleID)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 우리가 쥔 secure input을 반드시 되돌린다.
        TTYPasswordWatcher.shared.stop()
    }
}
