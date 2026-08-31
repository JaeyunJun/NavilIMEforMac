//
//  secure-run.swift
//  NavilIME 보조 도구
//
//  주어진 명령을 실행하는 동안만 secure input(EnableSecureEventInput)을 켠다.
//
//  왜 필요한가: macOS의 암호 입력 자리(잠금 화면, 키체인, 암호 필드)는 시스템이
//  secure input을 켜주지만, 터미널의 sudo 프롬프트는 켜주지 않는다. 터미널 앱이
//  pty의 에코 상태를 보지 않기 때문이다. 그래서 한글 입력 상태로 sudo 암호를 치면
//  한글이 들어가고, 사용자가 매번 수동으로 영문 전환해야 한다.
//
//  이 도구로 그 순간을 표시해 주면 NavilIME가 스스로 조합을 멈추고(영문),
//  덤으로 그동안 모든 이벤트 탭이 차단되어 실제 키로거 방어까지 된다.
//
//  사용:  secure-run sudo -v
//  .zshrc의 sudo 래퍼 함수와 함께 쓴다. README 참고.
//
//  빌드:  Tools/install.sh
//

import Carbon
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
    FileHandle.standardError.write("usage: secure-run <command> [args...]\n".data(using: .utf8)!)
    exit(64)
}

// secure input은 프로세스 전역 참조 카운트다. 켠 채로 죽으면 시스템 전체에서
// 이벤트 탭이 막히고 입력기가 조합을 멈춘다. 어떤 경로로 끝나든 반드시 되돌린다.
for sig in [SIGINT, SIGTERM, SIGHUP, SIGQUIT] {
    signal(sig) { _ in DisableSecureEventInput(); exit(130) }
}
atexit { DisableSecureEventInput() }

let enabled = (EnableSecureEventInput() == noErr)

// Foundation의 Process는 자식을 새 프로세스 그룹(세션)에 넣는다. 그러면 자식이
// 포그라운드 그룹이 아니게 되어, sudo가 tty에서 암호를 읽으려는 순간 SIGTTIN으로
// 멈춘다(프롬프트만 찍히고 입력이 안 먹는 증상). posix_spawnp를 attr 없이 직접
// 호출해 부모의 프로세스 그룹과 controlling tty를 그대로 물려준다.
var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
argv.append(nil)
defer { for p in argv where p != nil { free(p) } }

var pid: pid_t = 0
let rc = argv.withUnsafeMutableBufferPointer { buf in
    posix_spawnp(&pid, args[0], nil, nil, buf.baseAddress, environ)
}
guard rc == 0 else {
    DisableSecureEventInput()
    FileHandle.standardError.write("secure-run: \(args[0]): \(String(cString: strerror(rc)))\n".data(using: .utf8)!)
    exit(127)
}

var status: Int32 = 0
while waitpid(pid, &status, 0) == -1 && errno == EINTR {}

DisableSecureEventInput()
if !enabled {
    FileHandle.standardError.write("secure-run: secure input을 켜지 못했습니다\n".data(using: .utf8)!)
}

// 자식의 종료 상태를 그대로 전달한다. (Swift에는 WIFEXITED 등의 매크로가 없다.)
if status & 0x7f == 0 {
    exit((status >> 8) & 0xff)          // 정상 종료
} else {
    exit(128 + (status & 0x7f))         // 시그널로 종료
}
