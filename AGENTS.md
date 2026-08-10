# state

Agent-first system health CLI, one MFL source file (`src/state.src`), compiled
to a single static binary with [machin](https://github.com/javimosch/machin).

## What it is

```
uptime / free -m / df -h  -->  state binary  -->  OK | CAUTIOUS | CRITICAL
                                                  (human text, or --json)
```

CPU is a **load-average proxy** (`load1/nproc*100`), not an instantaneous
sample — see the `gotchas` in `state guide`. RAM and disk are straightforward
percentages. Thresholds are configurable and persisted at
`~/.config/state/config.json`.

## Build

```sh
./build.sh     # machin encode + machin build -> ./state
```

`machin check src/state.src --json` is the fast type-check-only loop (no `cc`
invocation) — run it before a full build while iterating.

## Install

```sh
./install.sh   # builds if stale, copies to ~/.local/bin/state
```

## Conventions

- One source file (`src/state.src`) — this tool is small on purpose; don't
  split it up unless it actually grows past a few hundred lines.
- Follows [cli-output-spec](https://github.com/javimosch/cli-output-spec)
  (typed errors, `help-json`, non-interactive no-op flags) and
  [cli-guide-spec](https://github.com/javimosch/cli-guide-spec) (`state guide`).
  Deliberately deviates on the **default report command's exit codes**:
  nagios-style `0/1/2` (OK/CAUTIOUS/CRITICAL) instead of the spec's `80-119`
  error ranges, because that's what monitoring tooling expects from a health
  check. `fail()` (actual errors) still uses the spec's ranges. Both are
  documented side-by-side in `state help-json` and `state guide`.
- `fail(code, type, msg, suggestion)` is the one error path — JSON body on
  stdout, matching exit code. Keep new error sites going through it.
- Config struct fields default to zero value; `load_config` treats a
  non-positive threshold as "use the built-in default" so a partially-written
  or hand-edited config file degrades gracefully instead of reporting 0%
  thresholds.

## Known gotcha worth remembering

`read_file("/proc/loadavg")` returns empty — pseudo-files under `/proc`
report size 0 via `stat`, which `read_file` relies on. Parse the 1-minute
load average out of `uptime`'s text output instead (see `loadavg1`).

## Releasing / distribution

No release automation yet (single binary, `git clone && ./install.sh` is the
whole story). If this grows multi-platform users, look at how
[machin-secure](https://github.com/javimosch/machin-secure) or
[grepapi](https://github.com/javimosch/grepapi) cut GitHub Releases with
cross-compiled binaries — same `machin build --target ...` story.
