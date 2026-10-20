# Contributing

Thanks for helping other Redrix owners. Bug reports with the output of `./verify.sh` are the most useful thing you can
send.

## Ground rules

- **English** for code, comments, commit messages and docs (`README.fr.md` is the one translation we keep in sync).
- **No language hard-coded.** Never parse translated tool output: run tools under `LC_ALL=C` (set by `lib/common.sh`)
  or use a machine interface (D-Bus, sysfs, `--json`).
- **Fix the cause.** No `|| true` that hides a failure, no retry loop, no special case for one machine.
- **Nothing personal or machine-specific.** No user names, UUIDs, serials, MAC addresses or paths of your machine.
  Detect at run time instead.
- **No third-party binaries or data in the repository.** Fetch them at a pinned commit or check a SHA-256, and add the
  source and license to `NOTICE.md`.
- **No source file over 500 lines.** Split along a real seam.

## Adding or changing a component

A component is a directory `components/<id>/` with a `component.sh` that sets the metadata (`TITLE`, `SUMMARY`, `RISK`,
`DEFAULT`, `ROOT`, `DEBIAN_PACKAGES`, `REQUIRES`, `CHANGES`, `ROLLBACK`) and defines `component_supported`,
`component_install`, `component_uninstall` and `component_verify`. Look at `components/camera/` for a small example.

- Register the id in `lib/components.sh` and write `docs/components/<id>.md` (background, what changes, rollback).
- `RISK=high` is for anything that can lock you out or stop the machine from booting (PAM, initramfs, bootloader).
  `RISK=medium` is for system-wide changes that are easy to undo. Only `low` components may be preselected.
- Install must be idempotent and must honour `--dry-run`: write through `run`, `as_root`, `as_root_write` and
  `install_if_changed` from `lib/common.sh`.
- Uninstall restores what was there before (see `gsettings_set_saved` and `saved_dir`) and removes exact paths only.
- Verify only reads. Every failure prints a hint the user can act on.

## Checks

```sh
shellcheck -x install.sh uninstall.sh verify.sh lib/*.sh components/*/*.sh scripts/*.sh tests/shell/*.sh
tests/run.sh
```

CI runs the same in `debian:testing`. On a Redrix, also run `./install.sh --dry-run <id>` and, after installing,
`./verify.sh <id>`, and paste the output in the pull request.

## Commits

Conventional Commits (`fix(speakers): ...`, `docs: ...`). One logical change per commit.
