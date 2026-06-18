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

    // 입력기는 사용자가 친 글자를 다루므로, 입력 내용이 시스템 로그에 평문으로
    // 남지 않도록 Release 빌드에서는 로그를 남기지 않는다. (디버깅은 Debug 빌드에서)
    func Log(log: @autoclosure () -> String) {
#if DEBUG
        os_log("%{public}@", log: self.logger, type: .debug, log())
#endif
    }
}
