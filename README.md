# shell-s2

One small, portable `u` command for daily shell work and for LLM agents that
need a predictable way to inspect and repair a machine.

- One file, `u`, written for bash 3.2+ (the macOS `/bin/bash`).
- No runtime, no package manager and no network at startup.
- Linux and macOS are the supported targets. Windows works through Git Bash
  (MSYS) on a best-effort basis.
- Commands are self-documenting: `u help`, `u help trash`, `u commands`.
- `*` in the command list marks a **daily** command (`#heavy` in the source).
- Public tree, private state: code, tests and `api.yaml` are here; the goal,
  takeover brief, current state, manual and failure queue are linked at
  `.agent/private/` and gitignored.

## Local private state

This is the public repository. On the owner's machine the private project state
(goal, takeover brief, current state, preferences, operations and failure
queue) is linked at `.agent/private/` and is gitignored. A fresh clone will not
have that link; this README and [`api.yaml`](api.yaml) are the public contract.
Maintainers should read `.agent/private/instruction.md` before changing code.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Truth1984/shell-s2/main/setup.sh | bash
```

Or from a checkout:

```sh
./setup.sh
```

The installer downloads `u` from the first reachable mirror, verifies it,
installs it as `~/.application/bin/u`, and runs `u setup` to add that directory
to your shell rc file. It does not change DNS, install packages or edit
anything else. Re-run it, or `u self-update`, to upgrade.

## Quick start

```sh
u help                       # grouped command list
u help find                  # usage and examples for one command
u commands                   # TSV: name, group, daily, summary

u os                         # mac arm64
u ip                         # public IPv4
u ip local                   # private IP
u trash ./old-build          # move to trash
u trash ls                   # id, time, size, original path
u trash undo <id>            # restore
u find "TODO" src            # content search (rg, ag, then grep)
u find --name "*.md" .       # file name search

u q add deploy 'cd ~/app && git pull && make'
u q deploy

u port 8080                  # who listens
u port kill 8080             # stop it, with confirmation
u proc --mem                 # top processes by memory
u screen                     # attach, or start when none exists

u dc up                      # docker compose up -d
u dk logs api -f             # docker logs
u svc restart nginx          # systemd, openrc, launchctl or sc
```

## Commands

`u help` prints this list with a one-line summary for every command. The stable
machine view is `u commands` (TSV) and `u --json commands`.

| Group | Commands |
| --- | --- |
| core | `*help`, `version`, `commands`, `*setup`, `self-update`, `*doctor`, `*os`, `has`, `env`, `*np`, `*pkg` |
| fs | `*trash`, `stat`, `*find`, `recent`, `zip` |
| text | `str`, `*date`, `b64`, `calc`, `*pw`, `uuid`, `clip` |
| net | `*ip`, `*get`, `post`, `*dl`, `dns` |
| proc | `*port`, `*pid`, `*proc`, `*screen` |
| dev | `*q`, `*clone`, `*g`, `*dk`, `*dc`, `*svc`, `*open`, `edit`, `log` |
| debug | `_ED`, `_RC`, `_path`, `_file`, `_selftest`, `_catalog` |

Debug commands start with `_` and are hidden from `u help` unless `--all` is
used. `_ED` always prints a debug line; `_RC` exits with a chosen code.

## Contract

- `u [--debug] [--json] [--yes] <command> [args...]`
- stdout is the result; stderr is the diagnostic.
- Exit codes: `0` ok, `1` failure or predicate false, `2` usage, `3` missing
  dependency, `4` environment, `5` conflict.
- Predicates (`u has`, `u str eq`, `u date older`, `u port free`, ...) are
  silent and communicate through the exit code.
- Prompts are only shown on a tty. In a non-interactive shell a command that
  needs confirmation fails with exit `2` instead of hanging. Pass `--yes`.
- `--json` is available on `version`, `commands` and `doctor`. The other
  commands print plain text because it is easier to pipe.

## Platform notes

| Concern | Linux | macOS | Windows (Git Bash) |
| --- | --- | --- | --- |
| Core commands | yes | yes | yes |
| `date` parsing | GNU date | BSD date | GNU date |
| `ip local` | `hostname -I` / `ip route` | `ipconfig` / `route` | `ipconfig` parsing |
| `port` | `ss`, `netstat` or `lsof` | `lsof` | `netstat -ano` |
| `proc`, `pid` | `ps`, `pgrep` | `ps`, `pgrep` | limited by the MSYS `ps` |
| `screen` | if installed | if installed | usually absent |
| `open` | `xdg-open` | `open` | `cmd.exe start` |
| `svc` | systemd or openrc | launchctl (status only) | `sc.exe` |

Accepted `date` inputs are explicit: `now`, epoch seconds, `YYYY-MM-DD`,
`YYYY-MM-DD HH:MM:SS` and `YYYY_MM_DD_HH_MM_SS`. Arbitrary natural-language
dates are deliberately not guessed.

## For LLM agents

The tool is designed to be called by an agent without a wrapper:

```sh
u commands --all             # every command, including debug helpers
u help <command>             # usage, examples, exit codes
u --json doctor              # platform, tools, disk, load as JSON
u has cmd curl               # silent, exit 0 or 1
u _ED "checking cache"       # explicit debug line on stderr
u _RC 3 "missing dependency" # debug line, then exit 3
u _path                      # directory containing u
```

Rules an agent can rely on:

- A non-zero exit is meaningful and documented per command.
- No command prompts when stdin is not a tty.
- No command writes to a path you did not name. The exceptions are
  `u setup` (your shell rc file) and `u pkg`/`u svc` (system changes).
- Read `u help <command>` before using an unfamiliar command; do not guess
  flags.

## State

| Path | Contents |
| --- | --- |
| `$U_DIR/bin` | installed `u` |
| `$U_DIR/quick` | quick commands created by `u q add` |
| `$U_DIR/.trash` | trash entries, one directory per entry |
| `$U_DIR` | defaults to `~/.application`, override with `U_DIR` |

Legacy shell-simple trash entries are still listed and restored.

## Migration from shell-simple

The surface moved from flags to subcommands. Old names still work where the
mapping is unambiguous.

| shell-simple | shell-s2 |
| --- | --- |
| `u trash -p path` | `u trash path` |
| `u ip -P` | `u ip local` |
| `u dates -D` | `u date fmt '%Y-%m-%d %H:%M:%S'` |
| `u string -c a b` | `u str contains a b` |
| `u process -k name` | `u proc kill name` |
| `u docker ...` | `u dk ...` (alias kept) |
| `u git ...` | `u g ...` (alias kept) |
| `u quick -a name cmd` | `u q add name cmd` |
| `u install name` | `u pkg install name` |
| `u upgrade` | `u pkg update` |
| `u syscheck` | `u doctor` |
| `u search text` | `u find text` |
| `u setupEX` | `u setup` then `u pkg` |

Removed on purpose: `tmux` (screen kept), `mount`, `scan`, `encrypt`,
`decrypt`, `encryptbun`, `decryptURL`, `_web`, `extra`, `fmt`, `network`,
`subdir`, `logfile`. They were rare, platform-specific, dangerous or better
served by the system tool (`python3 -m http.server`, `nmap`, `gpg`, `mount`).
`u log` replaces `logfile` for the common append-and-rotate case.

## Uninstall

```sh
rm -rf ~/.application
# then remove the "# >>> u >>>" block from your shell rc file
```

## Development

```sh
./u _selftest          # internal assertions
./test/run.sh          # CLI smoke and unit tests
/bin/bash ./u version  # bash 3.2 compatibility check
```

The public contract is [`api.yaml`](api.yaml) and the public proof is
`./test/run.sh`. Private design notes, operations and state live under
`.agent/private/` on the maintainer's machine. Keep this tree free of private
docs, personal paths and credentials.

## License

MIT. See [LICENSE](LICENSE).
