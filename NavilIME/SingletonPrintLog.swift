//
//  SingletonPrintLog.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/13/22.
//

import Foundation
import Cocoa

class PrintLog {
    static let shared = PrintLog()

    var scrollView: NSScrollView?
    
    private init() { }
    
    func Log(log: @autoclosure () -> String) {
        guard let scv = self.scrollView else {
            return
        }
        scv.documentView?.insertText(log() + "\n")
    }
}
