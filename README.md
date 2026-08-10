# state

An **agent-first** system health CLI. One ~53 KB static binary compiled from
[machin](https://github.com/javimosch/machin)/MFL. No Docker, no daemon, no
dependencies beyond `uptime`, `free`, `df`, and `nproc` (present on any Linux box).

```
$ state
state: CAUTIOUS
--------------------------------------------------------
CPU  : 24%  load 1.89/8 cores  [OK]
RAM  : 61%  used 18260MB / total 31836MB  [OK]
DISK : 94%  /  [CAUTIOUS]
--------------------------------------------------------
21:48:28 up 16 days, 12:38, 15 users,  load average: 1.89, 2.43, 2.18
```

`state` compares CPU load, RAM usage, and disk usage against configurable
thresholds and reports one of **OK**, **CAUTIOUS**, or **CRITICAL** — for a
human glancing at a terminal, or an agent polling `--json` in a loop.

## Install

```sh
git clone https://github.com/javimosch/state.git
cd state
./install.sh          # builds (needs machin: https://github.com/javimosch/machin) and copies to ~/.local/bin/state
```

Or just build without installing: `./build.sh`.

## Usage

```sh
state                  # human-friendly report
state --json           # machine-readable report, same data

state config           # show current thresholds (same as `state config get`)
state config set --cpu-warn 70 --cpu-crit 90 \
                  --ram-warn 75 --ram-crit 90 \
                  --disk-warn 80 --disk-crit 95 \
                  --disk-path /
state config reset     # restore defaults
state version          # binary version as JSON
state update --check   # check the content-hash manifest (exit 5 when newer)
state update           # verify, smoke-test and atomically install an update

state guide            # embedded agent skill (model/loop/concepts/gotchas)
state guide --human    # same, as markdown
state help-json        # machine-readable command catalog
state --help
```

## How it decides

| Metric | Source | Formula |
|---|---|---|
| CPU | `uptime`'s 1-minute load average | `load1 / nproc * 100` |
| RAM | `free -m` | `(total - available) / total * 100` |
| Disk | `df -h <path>` (default `/`) | the `Use%` column |

Each metric gets its own `warn`/`crit` percentage threshold (defaults: CPU
70/90, RAM 75/90, disk 80/95). `pct >= warn` → CAUTIOUS, `pct >= crit` →
CRITICAL, otherwise OK. The overall status is the worst of the three.
Thresholds persist per-user at `~/.config/state/config.json`.

## Exit codes

The default report command uses **nagios-style** exit codes, since that's
what monitoring scripts and agents already expect from a health check:

- `0` OK
- `1` CAUTIOUS
- `2` CRITICAL

Actual tool errors (bad flags, an unreadable disk path, …) use the
[cli-output-spec](https://github.com/javimosch/cli-output-spec) `80-119`
ranges instead — see `state help-json`.

## Updates

`state update` follows the content-hash update flow from
[cli-update-spec](https://github.com/javimosch/cli-update-spec): it hashes the
running binary, fetches a JSON manifest from `STATE_UPDATE_URL`, verifies the
candidate's short and optional full SHA-256, runs `state version` before any
swap, and keeps a `.bak-<hash>` rollback copy after a successful atomic rename.
Use `--check` for a non-mutating check (`0` up to date, `5` update available),
or `--force` to repair a matching but suspect binary. Relative `download` paths
resolve against `STATE_UPDATE_BASE` when set, otherwise the manifest URL origin.

## Agent-first

`state` follows the [agent-first CLI spec family](https://cli-specs.intrane.fr/):
JSON-by-default data on stdout, typed errors with semantic exit codes, a
`help-json` command catalog, and an embedded `guide` so an agent with only the
binary can learn the tool without external docs.

## License

MIT
