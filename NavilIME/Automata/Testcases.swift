//
//  Testcases.swift
//  automata
//
//  Created by Manwoo Yi on 9/10/22.
//

import Foundation
import Cocoa

class TestCase {

    var stdout_gui:NSScrollView?

    func test_debug(hangul:Hangul, t:String, ch:String, expect_commit:[String], expect_preedit: [String]) {
        var eaten:Bool = true

        if t == "input" {
            // 백스페이스
            if ch == "//b" {
                let _ = hangul.Backspace()
            } else {
                eaten = hangul.Process(ascii: ch)
                if eaten == false {
                    hangul.Flush()
                }
            }
        } else if t == "flush" {
            hangul.Flush()
        } else {
            assert(false)
        }

        var actual_commit = hangul.GetDebug(t: "commit")
        let actual_preedit = hangul.GetDebug(t: "preedit")

        if eaten == false {
            actual_commit.append(ch)
        }

        let commit_unicode:[unichar] = hangul.GetCommit()
        let preedit_unicode:[unichar] = hangul.GetPreedit()
        var commited:String = String(utf16CodeUnits:commit_unicode , count: commit_unicode.count)
        let preediting:String = String(utf16CodeUnits: preedit_unicode, count: preedit_unicode.count)

        if eaten == false {
            commited += ch
        }

        let result_str = "\(t) \(ch) commited \(expect_commit) = \(actual_commit) (\(commited)) preedited \(expect_preedit) = \(actual_preedit) (\(preediting))"
        print(result_str)

        assert(expect_commit == actual_commit)
        assert(expect_preedit == actual_preedit)
        _ = hangul.GetDebug(t: "clean")

        if let out_gui = self.stdout_gui {
            out_gui.documentView?.insertText(result_str + "\n")
        }
    }
}

class Test002 : TestCase {
    func run() {
        let hangul = Hangul()
        hangul.Start()

        print("========002===========")

        // 얇은 사 하이얀 고깔은
        // d i fq
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: [], expect_preedit: ["dXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "i", expect_commit: [], expect_preedit: ["diX"])
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: [], expect_preedit: ["dif"])
        self.test_debug(hangul: hangul, t: "input", ch: "q", expect_commit: [], expect_preedit: ["difq"])
        // d m s
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: ["difq"], expect_preedit: ["dXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "m", expect_commit: [], expect_preedit: ["dmX"])
        self.test_debug(hangul: hangul, t: "input", ch: "s", expect_commit: [], expect_preedit: ["dms"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["dms", " "], expect_preedit: [])
        // t k X
        self.test_debug(hangul: hangul, t: "input", ch: "t", expect_commit: [], expect_preedit: ["tXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: [], expect_preedit: ["tkX"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["tkX", " "], expect_preedit: [])
        // g k X
        self.test_debug(hangul: hangul, t: "input", ch: "g", expect_commit: [], expect_preedit: ["gXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: [], expect_preedit: ["gkX"])
        // d l X
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: [], expect_preedit: ["gkd"])
        self.test_debug(hangul: hangul, t: "input", ch: "l", expect_commit: ["gkX"], expect_preedit: ["dlX"])
        // d i s
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: [], expect_preedit: ["dld"])
        self.test_debug(hangul: hangul, t: "input", ch: "i", expect_commit: ["dlX"], expect_preedit: ["diX"])
        self.test_debug(hangul: hangul, t: "input", ch: "s", expect_commit: [], expect_preedit: ["dis"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["dis", " "], expect_preedit: [])
        // r h X
        self.test_debug(hangul: hangul, t: "input", ch: "r", expect_commit: [], expect_preedit: ["rXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "h", expect_commit: [], expect_preedit: ["rhX"])
        // R k f
        self.test_debug(hangul: hangul, t: "input", ch: "R", expect_commit: [], expect_preedit: ["rhR"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: ["rhX"], expect_preedit: ["RkX"])
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: [], expect_preedit: ["Rkf"])
        // d m s
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: ["Rkf"], expect_preedit: ["dXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "m", expect_commit: [], expect_preedit: ["dmX"])
        self.test_debug(hangul: hangul, t: "input", ch: "s", expect_commit: [], expect_preedit: ["dms"])
        self.test_debug(hangul: hangul, t: "flush", ch: "", expect_commit: ["dms"], expect_preedit: [])

        // 발바리 (밟 -> 발바 -> 발발 -> 발바리) 겹받침이었다가 다음 글자의 초성으로 한글자만 넘어가는것 테스트
        // q k f q k f l
        self.test_debug(hangul: hangul, t: "input", ch: "q", expect_commit: [], expect_preedit: ["qXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: [], expect_preedit: ["qkX"])
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: [], expect_preedit: ["qkf"])
        self.test_debug(hangul: hangul, t: "input", ch: "q", expect_commit: [], expect_preedit: ["qkfq"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: ["qkf"], expect_preedit: ["qkX"])
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: [], expect_preedit: ["qkf"])
        self.test_debug(hangul: hangul, t: "input", ch: "l", expect_commit: ["qkX"], expect_preedit: ["flX"])
        self.test_debug(hangul: hangul, t: "flush", ch: "", expect_commit: ["flX"], expect_preedit: [])

        // 고이 접어서 나빌레라.
        // r h X
        self.test_debug(hangul: hangul, t: "input", ch: "r", expect_commit: [], expect_preedit: ["rXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "h", expect_commit: [], expect_preedit: ["rhX"])
        // d l X
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: [], expect_preedit: ["rhd"])
        self.test_debug(hangul: hangul, t: "input", ch: "l", expect_commit: ["rhX"], expect_preedit: ["dlX"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["dlX", " "], expect_preedit: [])
        // w j q
        self.test_debug(hangul: hangul, t: "input", ch: "w", expect_commit: [], expect_preedit: ["wXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "j", expect_commit: [], expect_preedit: ["wjX"])
        self.test_debug(hangul: hangul, t: "input", ch: "q", expect_commit: [], expect_preedit: ["wjq"])
        // d j X
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: ["wjq"], expect_preedit: ["dXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "j", expect_commit: [], expect_preedit: ["djX"])
        // t j X
        self.test_debug(hangul: hangul, t: "input", ch: "t", expect_commit: [], expect_preedit: ["djt"])
        self.test_debug(hangul: hangul, t: "input", ch: "j", expect_commit: ["djX"], expect_preedit: ["tjX"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["tjX", " "], expect_preedit: [])
        // s k X
        self.test_debug(hangul: hangul, t: "input", ch: "s", expect_commit: [], expect_preedit: ["sXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: [], expect_preedit: ["skX"])
        // q l f
        self.test_debug(hangul: hangul, t: "input", ch: "q", expect_commit: [], expect_preedit: ["skq"])
        self.test_debug(hangul: hangul, t: "input", ch: "l", expect_commit: ["skX"], expect_preedit: ["qlX"])
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: [], expect_preedit: ["qlf"])
        // f p X
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: ["qlf"], expect_preedit: ["fXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "p", expect_commit: [], expect_preedit: ["fpX"])
        // f k X
        self.test_debug(hangul: hangul, t: "input", ch: "f", expect_commit: [], expect_preedit: ["fpf"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: ["fpX"], expect_preedit: ["fkX"])
        // .
        self.test_debug(hangul: hangul, t: "input", ch: ".", expect_commit: ["fkX", "."], expect_preedit: [])

        // 제 13의 아해가
        // w p X
        self.test_debug(hangul: hangul, t: "input", ch: "w", expect_commit: [], expect_preedit: ["wXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "p", expect_commit: [], expect_preedit: ["wpX"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["wpX", " "], expect_preedit: [])
        // 1
        self.test_debug(hangul: hangul, t: "input", ch: "1", expect_commit: ["1"], expect_preedit: [])
        // 3
        self.test_debug(hangul: hangul, t: "input", ch: "3", expect_commit: ["3"], expect_preedit: [])
        // d ml X
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: [], expect_preedit: ["dXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "m", expect_commit: [], expect_preedit: ["dmX"])
        self.test_debug(hangul: hangul, t: "input", ch: "l", expect_commit: [], expect_preedit: ["dmlX"])
        // " "
        self.test_debug(hangul: hangul, t: "input", ch: " ", expect_commit: ["dmlX", " "], expect_preedit: [])
        // d k X
        self.test_debug(hangul: hangul, t: "input", ch: "d", expect_commit: [], expect_preedit: ["dXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: [], expect_preedit: ["dkX"])
        // g o X
        self.test_debug(hangul: hangul, t: "input", ch: "g", expect_commit: [], expect_preedit: ["dkg"])
        self.test_debug(hangul: hangul, t: "input", ch: "o", expect_commit: ["dkX"], expect_preedit: ["goX"])
        // r k X
        self.test_debug(hangul: hangul, t: "input", ch: "r", expect_commit: [], expect_preedit: ["gor"])
        self.test_debug(hangul: hangul, t: "input", ch: "k", expect_commit: ["goX"], expect_preedit: ["rkX"])
        self.test_debug(hangul: hangul, t: "flush", ch: "", expect_commit: ["rkX"], expect_preedit: [])

        // ᄏᄏᄏᄏ 도ᅩᅩᅩᅩ
        self.test_debug(hangul: hangul, t: "input", ch: "z", expect_commit: [], expect_preedit: ["zXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "z", expect_commit: ["zXX"], expect_preedit: ["zXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "z", expect_commit: ["zXX"], expect_preedit: ["zXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "e", expect_commit: ["zXX"], expect_preedit: ["eXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "h", expect_commit: [], expect_preedit: ["ehX"])
        self.test_debug(hangul: hangul, t: "input", ch: "h", expect_commit: ["ehX"], expect_preedit: ["XhX"])
        self.test_debug(hangul: hangul, t: "input", ch: "h", expect_commit: ["XhX"], expect_preedit: ["XhX"])
        self.test_debug(hangul: hangul, t: "input", ch: "h", expect_commit: ["XhX"], expect_preedit: ["XhX"])
        self.test_debug(hangul: hangul, t: "flush", ch: "", expect_commit: ["XhX"], expect_preedit: [])

        self.test_debug(hangul: hangul, t: "input", ch: "g", expect_commit: [], expect_preedit: ["gXX"])
        self.test_debug(hangul: hangul, t: "input", ch: "o", expect_commit: [], expect_preedit: ["goX"])
        self.test_debug(hangul: hangul, t: "input", ch: "T", expect_commit: [], expect_preedit: ["goT"])
        self.test_debug(hangul: hangul, t: "input", ch: "S", expect_commit: ["goT"], expect_preedit: ["SXX"])
    }
}
