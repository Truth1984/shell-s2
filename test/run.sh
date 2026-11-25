#!/usr/bin/env bash
# shell-s2 test suite. No network. One file, no framework.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
U="$ROOT/u"
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t shell-s2)
trap 'rm -rf "$TMP"' EXIT
export U_DIR="$TMP/state"
export TZ=UTC
mkdir -p "$U_DIR"

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); }
bad() {
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

check_rc() {
  local desc=$1 want=$2
  shift 2
  "$@" >"$TMP/out" 2>"$TMP/err"
  local got=$?
  if [ "$got" -eq "$want" ]; then
    ok
  else
    bad "$desc (rc $got, want $want)"
    sed 's/^/  /' "$TMP/err" >&2
  fi
}

check_out() {
  local desc=$1 want=$2
  shift 2
  local got
  got=$(U_DIR="$U_DIR" "$@" 2>/dev/null)
  if [ "$got" = "$want" ]; then
    ok
  else
    bad "$desc (got [$got], want [$want])"
  fi
}

check_contains() {
  local desc=$1 needle=$2
  shift 2
  local got
  got=$(U_DIR="$U_DIR" "$@" 2>/dev/null)
  case "$got" in
    *"$needle"*) ok ;;
    *) bad "$desc (missing [$needle])" ;;
  esac
}

check_not_contains() {
  local desc=$1 needle=$2
  shift 2
  local got
  got=$(U_DIR="$U_DIR" "$@" 2>/dev/null)
  case "$got" in
    *"$needle"*) bad "$desc (unexpected [$needle])" ;;
    *) ok ;;
  esac
}

# --- syntax and identity ---------------------------------------------------
check_rc "bash -n u" 0 bash -n "$U"
check_rc "bash -n setup.sh" 0 bash -n "$ROOT/setup.sh"
check_out "version" "2.0.0" "$U" version
check_out "version json" '{"name":"u","version":"2.0.0"}' "$U" --json version
check_rc "help" 0 "$U" help
check_contains "help legend" "daily command" "$U" help
check_rc "help unknown" 2 "$U" help nope
check_rc "unknown command" 2 "$U" nope
check_rc "self test" 0 "$U" _selftest

# --- catalog and api.yaml parity -------------------------------------------
check_rc "commands all" 0 "$U" commands --all
bad_lines=$("$U" commands --all | awk -F'\t' 'NF != 4')
if [ -z "$bad_lines" ]; then ok; else bad "commands TSV has malformed rows"; fi
check_not_contains "debug hidden by default" "_ED" "$U" commands
check_contains "debug shown with --all" "_ED" "$U" commands --all
check_contains "help --all shows debug" "_selftest" "$U" help --all

"$U" commands --all | cut -f1 | sort >"$TMP/catalog"
sed -n 's/^  - name: //p' "$ROOT/api.yaml" | sort >"$TMP/api"
if diff -q "$TMP/catalog" "$TMP/api" >/dev/null 2>&1; then
  ok
else
  bad "api.yaml does not match the command catalog"
  diff -u "$TMP/catalog" "$TMP/api" >&2 || true
fi

"$U" commands --all | awk -F'\t' '$3 == 1 { print $1 }' | sort >"$TMP/heavy-catalog"
awk '/^  - name: / { n = $3 } /^    heavy: true/ { print n }' "$ROOT/api.yaml" | sort >"$TMP/heavy-api"
if diff -q "$TMP/heavy-catalog" "$TMP/heavy-api" >/dev/null 2>&1; then
  ok
else
  bad "api.yaml heavy flags do not match the catalog"
  diff -u "$TMP/heavy-catalog" "$TMP/heavy-api" >&2 || true
fi

while IFS=$'\t' read -r name _group _heavy _summary; do
  check_rc "help for $name" 0 "$U" "$name" --help
done < <("$U" commands --all)

# --- predicates and text ---------------------------------------------------
check_rc "has cmd sh" 0 "$U" has cmd sh
check_rc "has cmd missing" 1 "$U" has cmd no-such-command-xyz
check_rc "has env HOME" 0 "$U" has env HOME
check_rc "has env missing" 1 "$U" has env U_NO_SUCH_ENV_XYZ
check_out "env value" "$HOME" "$U" env HOME
check_out "env default" "fallback" "$U" env U_NO_SUCH_ENV_XYZ fallback

check_rc "str eq" 0 "$U" str eq a a
check_rc "str neq" 1 "$U" str eq a b
check_rc "str contains" 0 "$U" str contains "hello world" "lo wo"
check_rc "str num" 0 "$U" str num 123
check_rc "str not num" 1 "$U" str num 12a
check_out "str replace" "bbbc" "$U" str replace aaac a b
check_out "str upper" "ABC" "$U" str upper abc
check_out "str trim" "abc" "$U" str trim "  abc  "
check_out "str len" "3" "$U" str len abc

# --- date, base64, calc ----------------------------------------------------
check_out "date epoch 0" "0" "$U" date epoch 0
check_out "date show" "1970-01-01" "$U" date show 0 "%Y-%m-%d"
check_out "date plain parse" "1795608000" "$U" date epoch "2026_11_25_12_00_00"
check_out "date age" "31622400" "$U" date age 2020-01-01 2021-01-01
check_rc "date older true" 0 "$U" date older 2020-01-01 2021-01-01
check_rc "date older false" 1 "$U" date older 2021-01-01 2020-01-01
check_rc "date bad input" 2 "$U" date epoch "not-a-date"
check_out "b64 encode" "aGVsbG8=" "$U" b64 hello
check_out "b64 decode" "hello" "$U" b64 --decode aGVsbG8=
encoded=$(printf "hello" | "$U" b64)
if [ "$encoded" = "aGVsbG8=" ]; then ok; else bad "b64 stdin ($encoded)"; fi
decoded=$(printf "aGVsbG8=" | "$U" b64 --decode)
if [ "$decoded" = "hello" ]; then ok; else bad "b64 stdin decode ($decoded)"; fi
check_out "calc" "7" "$U" calc "1+2*3"
check_out "calc decimal" "2.5" "$U" calc "10/4"
check_rc "calc injection" 2 "$U" calc "1;rm -rf /"
uuid=$("$U" uuid)
case "$uuid" in
  ????????-????-????-????-????????????) ok ;;
  *) bad "uuid shape ($uuid)" ;;
esac

# --- filesystem ------------------------------------------------------------
check_rc "find content" 0 "$U" find "U_VERSION" "$U"
check_contains "find content line" 'U_VERSION="2.0.0"' "$U" find "U_VERSION" "$U"
check_rc "find no match" 1 "$U" find "no_such_string_xyz_123" "$U"
check_rc "find name" 0 "$U" find --name "u" "$ROOT"
check_rc "stat" 0 "$U" stat "$U"
check_contains "stat path" "$U" "$U" stat "$U"
if command -v python3 >/dev/null 2>&1; then
  if "$U" stat --json "$U" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["bytes"] > 0' 2>/dev/null; then
    ok
  else
    bad "stat --json is not valid JSON"
  fi
fi

mkdir -p "$TMP/work"
printf 'hello\n' >"$TMP/work/a.txt"
put=$("$U" trash "$TMP/work/a.txt")
id=${put%%$'\t'*}
case "$put" in
  *"$TMP/work/a.txt") ok ;;
  *) bad "trash receipt ($put)" ;;
esac
if [ ! -f "$TMP/work/a.txt" ]; then ok; else bad "trash did not move the file"; fi
check_contains "trash ls" "$id" "$U" trash ls
check_rc "trash undo" 0 "$U" trash undo "$id"
if [ -f "$TMP/work/a.txt" ]; then ok; else bad "trash undo did not restore the file"; fi
check_rc "trash undo missing" 1 "$U" trash undo "$id"
check_rc "trash protected path" 1 "$U" trash /

printf 'x\n' >"$TMP/work/b.txt"
"$U" trash "$TMP/work/b.txt" >/dev/null
check_rc "trash clean" 0 "$U" trash clean 0 --yes
check_out "trash empty after clean" "" "$U" trash ls

if "$U" recent 60 5 --base "$TMP/work" >/dev/null 2>&1; then ok; else bad "recent"; fi

# --- quick commands and log ------------------------------------------------
check_rc "q add" 0 "$U" q add hello "echo hi \"\$1\""
check_out "q run" "hi there" "$U" q hello there
check_contains "q list" "hello" "$U" q ls
check_rc "q cat" 0 "$U" q cat hello
check_rc "q rm" 0 "$U" q rm hello
if [ ! -f "$U_DIR/quick/hello" ]; then ok; else bad "q rm did not remove the command"; fi

for i in 1 2 3 4 5 6; do
  "$U" log --lines 3 "$TMP/app.log" "message $i"
done
if [ -f "$TMP/app.log" ] && grep -q "message 6" "$TMP/app.log"; then ok; else bad "log append"; fi
lines=$(wc -l <"$TMP/app.log" | tr -d ' ')
if [ "$lines" -le 3 ]; then ok; else bad "log rotation ($lines lines)"; fi

# --- archive (optional) ----------------------------------------------------
if command -v 7z >/dev/null 2>&1 || command -v 7za >/dev/null 2>&1 || command -v zip >/dev/null 2>&1; then
  mkdir -p "$TMP/z"
  printf 'zipme\n' >"$TMP/z/x.txt"
  if "$U" zip --out "$TMP/z.zip" "$TMP/z/x.txt" >/dev/null 2>&1; then
    ok
    if "$U" zip ls "$TMP/z.zip" >/dev/null 2>&1; then ok; else bad "zip ls"; fi
    if "$U" zip unzip "$TMP/z.zip" --dest "$TMP/zout" >/dev/null 2>&1 &&
      [ -f "$TMP/zout/x.txt" ]; then
      ok
    else
      bad "zip unzip"
    fi
  else
    bad "zip create"
  fi
fi

# --- platform and services -------------------------------------------------
check_rc "os" 0 "$U" os
check_rc "os pkg" 0 "$U" os pkg
case "$(uname -s 2>/dev/null)" in
  Darwin) check_rc "os is mac" 0 "$U" os is mac ;;
  *) check_rc "os is linux" 0 "$U" os is linux ;;
esac
check_rc "doctor" 0 "$U" doctor
if command -v python3 >/dev/null 2>&1; then
  if "$U" --json doctor | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "deps" in d and "load" in d' 2>/dev/null; then
    ok
  else
    bad "doctor --json is not valid JSON"
  fi
  if "$U" --json commands | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d) > 30' 2>/dev/null; then
    ok
  else
    bad "commands --json is not valid JSON"
  fi
fi
check_rc "dc without compose" 3 "$U" dc up
check_rc "clone usage" 2 "$U" clone
check_rc "g log" 0 "$U" g log 3
check_rc "g st" 0 "$U" g st

if command -v screen >/dev/null 2>&1; then
  check_rc "screen ls" 0 "$U" screen ls
fi

# --- aliases ---------------------------------------------------------------
check_rc "alias string" 0 "$U" string eq a a
check_out "alias b64d" "hello" "$U" b64d aGVsbG8=
check_rc "alias sf help" 0 "$U" sf --help
check_rc "alias process help" 0 "$U" process --help
check_rc "alias download-git help" 0 "$U" download-git --help
check_rc "nested pkg help" 0 "$U" pkg install --help
check_rc "nested g help" 0 "$U" g reset --help
check_rc "nested q help" 0 "$U" q add --help

# --- setup and self-update (local only) ------------------------------------
mkdir -p "$TMP/home"
if HOME="$TMP/home" U_DIR="$TMP/setup" "$U" setup --no-rc >/dev/null 2>&1 &&
  [ -x "$TMP/setup/bin/u" ]; then
  ok
else
  bad "setup --no-rc"
fi
mkdir -p "$TMP/home2"
HOME="$TMP/home2" U_DIR="$TMP/setup2" "$U" setup >/dev/null 2>&1
rc_file=$(ls "$TMP/home2"/.zshrc "$TMP/home2"/.bashrc "$TMP/home2"/.bash_profile 2>/dev/null | head -n 1)
if [ -n "$rc_file" ] && grep -qF '# >>> u >>>' "$rc_file"; then
  ok
else
  bad "setup rc block"
fi
check_out "installed copy version" "2.0.0" "$TMP/setup/bin/u" version

ver=$("$U" version)
sed "s/^U_VERSION=\"$ver\"/U_VERSION=\"9.9.9\"/" "$U" >"$TMP/fake-u"
chmod +x "$TMP/fake-u"
if U_DIR="$TMP/update" U_UPDATE_URL="file://$TMP/fake-u" "$U" self-update >/dev/null 2>&1; then
  ok
else
  bad "self-update"
fi
check_out "self-update installed version" "9.9.9" "$TMP/update/bin/u" version

# --- bash 3.2 compatibility ------------------------------------------------
if [ -x /bin/bash ]; then
  check_rc "bash /bin/bash version" 0 /bin/bash "$U" version
  check_rc "bash /bin/bash self test" 0 /bin/bash "$U" _selftest
  check_rc "bash /bin/bash find" 0 /bin/bash "$U" find "U_VERSION" "$U"
  check_rc "bash /bin/bash date" 0 /bin/bash "$U" date epoch 0
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
