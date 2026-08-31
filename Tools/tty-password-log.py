#!/usr/bin/env python3
"""
TTYPasswordWatcher가 무엇에 반응하는지 기록한다. (오탐 추적용)

NavilIME는 tty가 "정규 모드(ICANON) + 에코 끔(ECHO off)"이면 암호 프롬프트로 보고
한글 조합을 멈춘다. 이 스크립트는 같은 조건을 독립적으로 감시해서, 그 상태가
생길 때마다 어떤 프로그램 때문인지 남긴다.

한글이 갑자기 안 조합되면 이 로그를 보면 된다. sudo/ssh 같은 게 아니라면 오탐이다.

사용:
    python3 Tools/tty-password-log.py                      # 화면에 출력
    nohup python3 Tools/tty-password-log.py \
        > ~/Library/Logs/NavilIME-tty.log 2>&1 &           # 백그라운드로 계속
"""

import glob, os, subprocess, sys, termios, time
from datetime import datetime

POLL = 0.5   # 초


def password_state_ttys():
    """정규 모드 + 에코 꺼짐인 tty 목록. NavilIME와 같은 판정 기준."""
    uid = os.getuid()
    found = []
    for dev in glob.glob("/dev/ttys*"):
        try:
            if os.stat(dev).st_uid != uid:
                continue
            fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK | os.O_NOCTTY)
        except OSError:
            continue
        try:
            lflag = termios.tcgetattr(fd)[3]
            if (lflag & termios.ICANON) and not (lflag & termios.ECHO):
                found.append(dev)
        except Exception:
            pass
        finally:
            os.close(fd)
    return set(found)


def who_is_on(dev):
    """그 tty에 붙은 프로세스들. 포그라운드(입력을 실제로 읽는 것)를 앞에 둔다."""
    name = os.path.basename(dev)
    try:
        out = subprocess.run(["ps", "-t", name, "-o", "pid=,pgid=,tpgid=,comm="],
                             capture_output=True, text=True, timeout=3).stdout
    except Exception:
        return "(조회 실패)"
    fg, bg = [], []
    for line in out.strip().splitlines():
        parts = line.split(None, 3)
        if len(parts) < 4:
            continue
        _, pgid, tpgid, comm = parts
        comm = os.path.basename(comm)
        (fg if pgid == tpgid else bg).append(comm)
    if not fg and not bg:
        return "(프로세스 없음)"
    head = ", ".join(dict.fromkeys(fg)) or "?"
    tail = ", ".join(dict.fromkeys(bg))
    return f"{head}" + (f"   [배경: {tail}]" if tail else "")


def stamp():
    return datetime.now().strftime("%m-%d %H:%M:%S")


def main():
    print(f"  감시 시작 ({stamp()}). 한글이 안 될 때 이 로그를 보세요. Ctrl-C로 종료.")
    print("  정상이면 sudo / ssh / git / passwd 같은 것만 찍힙니다.\n", flush=True)
    active = set()
    while True:
        try:
            now = password_state_ttys()
        except Exception as e:
            print(f"  {stamp()}  스캔 오류: {e}", flush=True)
            time.sleep(POLL)
            continue
        for dev in sorted(now - active):
            print(f"  {stamp()}  감지  {dev}  ←  {who_is_on(dev)}", flush=True)
        for dev in sorted(active - now):
            print(f"  {stamp()}  해제  {dev}", flush=True)
        active = now
        time.sleep(POLL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n  종료.")
