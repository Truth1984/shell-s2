# Entry: shell-s2

Public repository map. Private project state is not tracked here. On the
owner's machine it is linked at `.agent/private/`, which is gitignored.

`u` is one small, portable CLI for daily shell work and for LLM agents. It is a
single bash file with no runtime dependency, plus an installer and a test.

## Contents

| Path | Kind | What it does |
| --- | --- | --- |
| `README.md` | file | Public overview, install, command groups, migration, private-state pointer. |
| `Entry.md` | file | This map. |
| `u` | file | The entire CLI. Commands, help, dispatch and debug helpers. |
| `setup.sh` | file | Download-verify-install bootstrap; runs `u setup`. |
| `api.yaml` | file | The only command and flag contract. |
| `test/` | dir | Public CLI smoke and unit tests, bash 3.2 and bash 5. |
| `LICENSE` | file | MIT. |
| `.gitignore` | file | Ignores local wiring, logs and OS noise. |
| `.agent/` | dir | Local only: `knowledge`, `bin`, `private` symlinks; gitignored. |

## Read order

`README.md` -> `Entry.md` -> `api.yaml` -> `test/run.sh` ->
`.agent/private/instruction.md` (when the private link exists).

## Boundary

- One role: a tool. It does not encode a consumer's workflow.
- Public: code, tests, `api.yaml`, install and migration notes.
- Private, never in this tree: goal, takeover brief, current state, preferences,
  operations manual, failure queue and project workflows. Read them through
  `.agent/private/` on the owner's machine.
- A cross-project change is an issue under `shell-s2-bot`, never an edit in
  another repository.
- No personal path, credential, goal or state belongs in a public file.

## Commands

```sh
./u help
./u help <command>
./u commands --all
./u _selftest
./test/run.sh
```
