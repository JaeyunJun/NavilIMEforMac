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
echo "다음을 ~/.zshrc 에 추가하면 sudo 암호 프롬프트에서 입력기가 자동으로 비켜선다:"
echo
sed -n '/^# >>> NavilIME/,/^# <<< NavilIME/p' "$DIR/zshrc-snippet.sh"
