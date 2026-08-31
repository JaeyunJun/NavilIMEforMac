# >>> NavilIME secure-run >>>
# sudo 암호 프롬프트 동안만 secure input을 켠다.
# → NavilIME가 스스로 조합을 멈춰 영문이 들어가고, 그 순간 이벤트 탭도 차단된다.
# sudo -v 는 암호만 확인하고 즉시 끝나므로 프롬프트 동안만 잡힌다.
# (sudo vim 같은 걸 써도 편집 중에는 한글이 정상 동작한다.)
sudo() {
  case "$1" in
    -k|-K|-n) command sudo "$@" ;;
    *) secure-run sudo -v && command sudo "$@" ;;
  esac
}
# <<< NavilIME secure-run <<<
