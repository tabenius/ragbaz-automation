# ragbaz-automation

Host automation for the RAGBAZ workspace: scheduled jobs that run as a user on
a workstation, installed as user-level systemd units.

The workspace itself is a collection of independent repositories under
`/srv/ragbaz/src/vendors/ragbaz/head`. This repository holds the jobs that tie
them to a clock. It used to be an unversioned directory inside that workspace,
which is how a stale path survived unnoticed: nothing owned it, so nothing
noticed that a relocated workspace had broken a timer that had never run.

## Principles

- **Resolve paths from the running script.** `install.sh` and `run.sh` derive
  the workspace from their own location and rewrite the unit's absolute paths.
  A hardcoded home directory is a bug the moment the checkout moves.
- **A timer that has never run is not a working timer.** Check the journal, not
  the unit file.
- **Fail loudly.** A missing skill or an unwritable report directory exits
  non-zero rather than producing a silently empty report.

## Jobs

| Job | Schedule | What it does |
|---|---|---|
| `weekly-review` | Mondays 09:00 Europe/Stockholm | Builds the weekly project report and social draft from local evidence via Codex, falling back to local OpenCode models when Codex is unavailable. |

### Install

```sh
./weekly-review/install.sh
```

Installs the user units, copies the skill into `~/.codex/skills/`, and enables
the timer. Re-run it after moving a checkout; it rewrites the unit's paths.

## Host facts

Box-local paths, image pins and schedules are not committed here; they are
rewritten at install time. What stays in the repository is the method.