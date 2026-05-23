//
//  SingletonPrintLog.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/13/22.
//

import Foundation
import os.log

class PrintLog {
    static let shared = PrintLog()

    private let logger = OSLog(subsystem: "io.navilera.NavilIME", category: "ime")

    private init() { }

    func Log(log: @autoclosure () -> String) {
        os_log("%{public}@", log: self.logger, type: .debug, log())
    }
}
