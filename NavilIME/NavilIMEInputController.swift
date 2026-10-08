//
//  NavilIMEInputController.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/4/22.
//

import InputMethodKit
import Carbon

@objc(NavilIMEInputController)
open class NavilIMEInputController: IMKInputController {
    let key_code:String =       "asdfhgzxcv\tbqweryt123465=97-80]ou[ip\tlj'k;\\,/nm.\t `"
    let shift_key_code:String = "ASDFHGZXCV\tBQWERYT!@#$^%+(&_*)}OU{IP\tLJ\"K:|<?NM>\t ~"
    
    var hangul:Hangul?

    // 마지막으로 입력을 받은 클라이언트의 번들 ID. menu()에는 클라이언트가 넘어오지
    // 않으므로, 트레이 메뉴가 "이 앱"을 알려면 여기에 남겨둬야 한다.
    // 컨트롤러는 클라이언트마다 새로 만들어지므로 static이어야 한다.
    static var last_client_bundle_id:String?

    // 지금 입력을 받고 있는 컨트롤러. SpecialKeyTap(탭 스레드)이 "한글 입력기가 켜져 있나"를
    // 판단하고 특수키를 넘겨주는 데 쓴다. 탭 스레드와 메인 스레드가 함께 만지므로 잠금으로 보호한다.
    private static let active_lock = NSLock()
    private static weak var active_controller:NavilIMEInputController?
    static var active:NavilIMEInputController? {
        active_lock.lock()
        defer { active_lock.unlock() }
        return active_controller
    }
    private static func set_active(_ ctl:NavilIMEInputController?, only_if current:NavilIMEInputController? = nil) {
        active_lock.lock()
        defer { active_lock.unlock() }
        if current == nil || active_controller === current {
            active_controller = ctl
        }
    }

    override open func activateServer(_ sender: Any!) {
        super.activateServer(sender)

        PrintLog.shared.Log(log: "Server Activated")
        Self.set_active(self)
        self.hangul = Hangul()
        self.hangul?.Start()
        self.apply_app_lang(client: sender)
    }

    // Raycast 같은 런처는 '비활성화 패널'로 떠서 앱 활성화 알림이 오지 않는 경우가 있다.
    // 그때는 IMK가 새 클라이언트로 입력기를 활성화하는 이 경로가 유일한 신호다.
    // 같은 앱 안에서의 재활성화(⌘Space로 직접 전환)는 AppLangHandler가 걸러낸다.
    func apply_app_lang(client:Any!) {
        guard let bundle_id = (client as? IMKTextInput)?.bundleIdentifier() else { return }
        Self.last_client_bundle_id = bundle_id
        AppLangHandler.shared.apply_on_activate(bundle_id: bundle_id)
    }

    override open func deactivateServer(_ sender: Any!) {
        PrintLog.shared.Log(log: "Server deactivating")

        // 세션을 정리(super)하기 전에 조합 중이던 글자를 이전 client로 먼저 확정한다.
        // super를 먼저 부르면 포커스가 새 앱으로 넘어간 뒤 commit돼, 그 글자가
        // 새 창(예: Raycast)으로 새어 "이전 입력기 것과 섞이는" 현상이 생길 수 있다.
        self.hangul?.Flush()
        self.update_display(client: sender)
        self.hangul?.Stop()

        // 다른 컨트롤러가 이미 활성화됐다면(deactivate가 늦게 오는 경우) 그쪽을 지우지 않는다.
        Self.set_active(nil, only_if: self)
        super.deactivateServer(sender)
    }
    
    // hangul이 없거나 automata가 nil이면 복구한다.
    // macOS가 activateServer 없이 handle을 호출하는 경우 대비.
    func ensureHangulReady() {
        if self.hangul == nil {
            self.hangul = Hangul()
        }
        if self.hangul?.automata == nil {
            self.hangul?.Start()
        }
    }

    override open func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        self.ensureHangulReady()

        switch event.type {
        case .keyDown:
            let eaten = self.keydown_event_handler(event: event, client: sender)
            if eaten == false {
                self.commitComposition(sender)
            }
            return eaten
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            self.commitComposition(sender)
        default:
            PrintLog.shared.Log(log: "unhandled event keycode=\(event.keyCode) modi=\(event.modifierFlags.rawValue)")
        }
        return false
    }
    
    func keydown_event_handler(event:NSEvent, client:Any!) -> Bool {
        guard let hangul = self.hangul else { return false }

        let keycode = event.keyCode
        let flag = event.modifierFlags

        // secure input이 켜진 동안(sudo 암호 프롬프트, 잠금 해제, 암호 필드 등)에는
        // 조합하지 않고 키를 그대로 흘려보낸다. macOS는 이 상황에서 입력 소스를 영문으로
        // 갈아주지 않으므로(확인함), 입력기가 스스로 비켜야 암호가 제대로 들어간다.
        //
        // 입력 소스는 건드리지 않는다 — 프롬프트를 빠져나오면 원래 상태 그대로다.
        // 호출 비용은 ~4ns라 매 키 입력마다 확인해도 무방하다.
        //
        // [주의] secure input은 프로세스 전역 참조 카운트라, 어떤 앱이 켜놓고 끄지 않으면
        // 한글이 어디서도 조합되지 않는다. 그 증상이면 화면을 잠갔다 풀면 풀린다.
        if IsSecureEventInputEnabled() || TTYPasswordWatcher.shared.isPasswordPromptActive() {
            hangul.Flush()
            self.update_display(client: client)
            return false
        }

        // 특정 패턴 입력은 한글로 변환하지 않는다.
        // 단축키(cmd/option/control)와 함께 들어온 keycode는 hotfix 패턴에 섞으면 false-positive가 생기므로 제외.
        if !flag.contains(.command) && !flag.contains(.option) && !flag.contains(.control) {
            Hotfix.shared.add(keycode)
            if Hotfix.shared.check() {
                return false
            }
        }

        if flag.contains(.command)
            || flag.contains(.option)
            || flag.contains(.control) {
            PrintLog.shared.Log(log: "Modikey - \(keycode) with \(flag.rawValue)")
            return false
        }

        let enter_return:UInt16 = 0x24
        let tab:UInt16 = 0x30
        if keycode == enter_return || keycode == tab {
            PrintLog.shared.Log(log: "Enter or Tab")

            hangul.Flush()
            self.update_display(client: client)

            return false
        }

        let backspace:UInt16 = 0x33
        if keycode == backspace {
            PrintLog.shared.Log(log: "Backspace")

            let remain = hangul.Backspace()
            if remain {
                self.update_display(client: client, backspace: true)
            }
            return remain
        }

        if keycode >= self.key_code.count {
            PrintLog.shared.Log(log: "Bypassd keycode: \(keycode) >= \(self.key_code.count)")

            hangul.Flush()
            self.update_display(client: client)

            return false
        }

        let ascii_idx = self.key_code.index(self.key_code.startIndex, offsetBy: Int(keycode))
        var ascii = self.key_code[ascii_idx]
        if flag.contains(.shift) {
            ascii = self.shift_key_code[ascii_idx]
        }

        let is_hangul:Bool = hangul.Process(ascii: String(ascii))
        if is_hangul == false {
            PrintLog.shared.Log(log: "Not Hangul: \(ascii)")

            hangul.Flush()
            self.update_display(client: client, backspace: false, additional: String(ascii))
        } else {
            self.update_display(client: client)
        }
        return true
    }
    
    // SpecialKeyTap이 메인 스레드에서 부른다. 탭은 한글 입력기가 켜져 있으면 특수키 이벤트를
    // 삼키고 여기로 넘긴다 — 탭이 문자를 바꿔 넣은 이벤트는 입력기의 handle까지 오지 않기
    // 때문이다(로그로 확인). 조합 중인 글자를 먼저 확정하고 그 뒤에 붙인다.
    func insert_special(_ output:String) {
        guard let client = self.client() else { return }
        self.ensureHangulReady()
        self.hangul?.Flush()
        self.update_display(client: client, additional: output)
    }

    func update_display(client:Any!, backspace:Bool = false, additional:String = "") {
        let commit_unicode:[unichar] = self.hangul?.takeCommit() ?? []
        let preedit_unicode:[unichar] = self.hangul?.takePreedit() ?? []
        
        // 출력할 내용이 전혀 없으면 IMKTextInput 호출을 건너뛴다.
        if commit_unicode.isEmpty && preedit_unicode.isEmpty && additional.isEmpty && backspace == false {
            return
        }
        
        var commited:String = ""
        if commit_unicode.isEmpty == false {
            commited = String(utf16CodeUnits:commit_unicode , count: commit_unicode.count)
        }
        
        var preediting:String = ""
        if preedit_unicode.isEmpty == false {
            preediting = String(utf16CodeUnits: preedit_unicode, count: preedit_unicode.count)
        }
        
        PrintLog.shared.Log(log: "C:'\(commited)' - \(commited.count) P:'\(preediting)' - \(preediting.count)")
        
        guard let disp = client as? IMKTextInput else {
            return
        }
        
        commited += additional
        
        let build_count = 302
        if commited.isEmpty == false {
            disp.insertText(commited, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            
            PrintLog.shared.Log(log: "\(build_count) Commit: \(commited)")
        }
        
        // replacementRange 가 아래 코드와 같아야만 잘 동작한다.
        if (preediting.isEmpty == false) || (backspace == true) {
            // 백스페이스로 글자를 지울 때, preddition.count == 0 인 상태가 되는데
            // 이 때 명시적으로 length = 0 인 NSRange를 setMarkedText()에 주어야만 자연스럽게 처리된다.
            // NSRange.length는 UTF-16 단위. NFD로 분해된 한글은 grapheme count와 다르므로 NSString.length를 쓴다.
            let sr = NSRange(location: 0, length: (preediting as NSString).length)
            let rr = NSRange(location: NSNotFound, length: NSNotFound)
            PrintLog.shared.Log(log: "RR: \(rr) SR: \(sr) on \(String(describing: disp.bundleIdentifier()))")
            disp.setMarkedText(preediting, selectionRange: sr, replacementRange: rr)
            
            PrintLog.shared.Log(log: "\(build_count) Predit: \(preediting)")
        }
    }
    
    /*
     입력 메서드가 이 메서드를 구현하면, 클라이언트가 컴포지션 세션을 즉시 종료하고자 할 때 호출됩니다.
     일반적인 응답은 클라이언트의 insertText 메서드를 호출한 다음 세션별 버퍼와 변수를 정리하는 것입니다.
     이 메시지를 받은 후 입력 방법은 주어진 컴포지션 세션이 완료된 것을 고려해야 합니다.
     */
    override open func commitComposition(_ sender: Any!) {
        PrintLog.shared.Log(log: "Commit Composition")
        self.hangul?.Flush()
        self.update_display(client: sender)
    }
    
    /*
     클라이언트는 입력 메서드가 이벤트를 지원하는지 확인하기 위해 이 메서드를 호출합니다.
     기본 구현은 NSKeyDownMask를 반환합니다.
     입력 방법이 키 다운 이벤트만 처리하는 경우, 입력 방법 키트는 기본 마우스 처리를 제공합니다.
     기본 마우스다운 처리 동작은 다음과 같습니다:
       활성 컴포지션 영역이 있고 사용자가 텍스트를 클릭하지만 컴포지션 영역 외부에서 클릭하는 경우,
       입력 방법 키트는 입력 메서드에 commitComposition: 메시지를 보냅니다.
       이것은 기본값인 NSKeyDownMask만 반환하는 입력 메서드에서만 발생합니다.
     */
    override open func recognizedEvents(_ sender: Any!) -> Int {
        // drag는 frame마다 들어와 매번 commit이 호출되므로 제외.
        return Int(NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged,
            .leftMouseUp, .rightMouseUp, .leftMouseDown, .rightMouseDown,
            .appKitDefined, .applicationDefined, .systemDefined).rawValue)
    }
    
    /*
     마우스 버튼이 눌리면 현재 조합을 종료하고 커밋
     */
    override open func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint, withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!, client sender: Any!) -> Bool {
        PrintLog.shared.Log(log: "Mouse Down")
        
        self.commitComposition(sender)
        return false
    }
    
    
    /*
     이 메서드는 입력 메서드가 현재 상태를 반영하도록 메뉴를 업데이트할 수 있도록 메뉴를 그려야 할 때마다 호출됩니다.
     */
   override open func menu() -> NSMenu! {
        // 권한이 방금 허용됐다면 탭을 켜고, 메뉴 표시 상태도 갱신한다.
        SpecialKeyTap.shared.startIfTrusted()
        HangulMenu.shared.refresh_permission_state()
        HangulMenu.shared.refresh_app_lang_state()
        return HangulMenu.shared.menu
   }
    
    /*
     IMKit 프레임워크는 실제 NSMenu 객체가 어디에 있건간에 NSMenuItem.action은 무조건 InputController 내부에 있어야 한다.
     그리고 sender는 NSMenuItem이 아니다. <-- 졸라 중요.
     IMKit에서 생성한 Dictionary 타입 객체가 sender로 전달된다.
     거기서 NSMenuItem을 찾으려면 ["IMKCommandMenuItem"]으로 Dictionary에서 값을 가져와야 한다.
     인터넷 그 어디에도 공식적인 문서 자료가 없다. 내가 삽질해서 찾은 것임.
     */
    // 지금 입력 중인 앱의 한/영을 고정하거나 해제한다. 고른 즉시 반영된다.
    @objc func select_app_lang(_ sender:Any?) {
        self.hangul?.Flush()
        guard let dict = sender as? [String: Any],
              let item = dict["IMKCommandMenuItem"] as? NSMenuItem,
              let bundle_id = Self.last_client_bundle_id,
              let lang = AppLang(rawValue: item.tag) else {
            return
        }
        AppLangHandler.shared.set(lang, for: bundle_id)
        HangulMenu.shared.refresh_app_lang_state()
        AppLangHandler.shared.apply_on_activate(bundle_id: bundle_id)
    }

    // 특수키(₩, ~, `)는 전역 이벤트 탭이 유일한 처리 경로라 손쉬운 사용 권한이 필요하다.
    // 실제 권한·탭 상태를 보여주고 설정으로 보내는 상태 창을 연다. (PermissionWindow 참조)
    @objc func grant_special_key_permission(_ sender:Any?) {
        PermissionWindow.shared.show()
    }
}
