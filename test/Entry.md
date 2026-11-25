# Entry: test

Tests are runnable documentation: one suite, no network, no framework.

## Contents

| Path | Kind | What it does |
| --- | --- | --- |
| `run.sh` | file | CLI smoke and unit tests; exits non-zero on failure. |

## Rules

- `./test/run.sh` must pass before a commit.
- The suite uses a temporary `U_DIR`; it never touches `~/.application`.
- No network. `self-update` and `setup` are tested with `file://` URLs.
- `api.yaml` must match `u commands --all`; the suite diffs the two lists.
- Every catalog command must answer `u <command> --help`.
- The same suite runs on `/bin/bash` (3.2 on macOS) and on the default bash.
