#!/usr/bin/env bash
# shell-s2 installer.
# Usage: curl -fsSL <raw>/setup.sh | bash
#        ./setup.sh
#
# It downloads `u` from the first reachable mirror, verifies it, installs it
# under $U_DIR/bin (default ~/.application/bin) and runs `u setup`.
# It does not change DNS, install packages or edit anything outside the shell
# rc file that `u setup` manages.

SCRIPT_VERSION="2.0.0"
REPO="Truth1984/shell-s2"
BRANCH="main"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}/u"

U_DIR="${U_DIR:-$HOME/.application}"
case "$U_DIR" in
  "~") U_DIR="$HOME" ;;
  "~/"*) U_DIR="$HOME/${U_DIR#\~/}" ;;
esac
BIN="$U_DIR/bin"

say() {
  printf '%s\n' "$*"
}

die() {
  printf 'setup: %s\n' "$*" >&2
  exit 1
}

download() {
  local url=$1 out=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 1 --max-time 30 -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$out" "$url"
  else
    die "curl or wget is required"
  fi
}

command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 ||
  die "curl or wget is required"

mkdir -p "$BIN" || die "cannot create $BIN"
TMP="$BIN/.u.$$"

URLS=""
if [ -n "${U_UPDATE_URL:-}" ]; then
  URLS="$U_UPDATE_URL
"
fi
URLS="${URLS}https://fastgit.cc/${RAW}
https://cdn.akaere.online/${RAW}
https://ghproxy.monkeyray.net/${RAW}
http://ghfast.top/${RAW}
http://gh.ddlc.top/${RAW}
${RAW}"

ok=0
while IFS= read -r url; do
  [ -n "$url" ] || continue
  say "trying $url"
  if download "$url" "$TMP" 2>/dev/null && [ -s "$TMP" ] &&
    head -n 1 "$TMP" | grep -q '^#!/usr/bin/env bash' &&
    grep -q '^U_VERSION=' "$TMP" &&
    bash -n "$TMP" 2>/dev/null; then
    ok=1
    break
  fi
done <<EOF
$URLS
EOF

if [ "$ok" != 1 ]; then
  rm -f "$TMP"
  die "could not download a valid u from any mirror"
fi

chmod 755 "$TMP" || die "cannot chmod $TMP"
mv -f "$TMP" "$BIN/u" || die "cannot install $BIN/u"

say "installed $("$BIN/u" version) at $BIN/u"
if [ "${U_NO_RC:-0}" = 1 ]; then
  "$BIN/u" setup --no-rc || die "u setup failed"
else
  "$BIN/u" setup || die "u setup failed"
fi
say "done. open a new shell, or run: export PATH=\"$BIN:\$PATH\""
