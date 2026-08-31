#!/bin/sh
# secure-run을 빌드해서 ~/.local/bin 에 설치한다.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
DEST="$HOME/.local/bin"
mkdir -p "$DEST"
for tool in secure-run secure-test; do
  swiftc -O "$DIR/$tool.swift" -o "$DEST/$tool"
  echo "설치됨: $DEST/$tool"
done
echo
echo "암호 프롬프트 감지는 앱(TTYPasswordWatcher)이 자동으로 합니다 — 셸 설정은 필요 없습니다."
echo "감지가 안 먹는 명령이 있으면 'secure-run <명령>' 으로 직접 감싸면 됩니다."
echo
echo "sudo를 항상 감싸고 싶다면 zshrc-snippet.sh 의 함수를 ~/.zshrc 에 넣으세요 (선택)."
