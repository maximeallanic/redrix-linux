## What and why

<!-- What does this change, and what problem does it solve? -->

Fixes #

## How I checked it

<!-- Commands you ran; on a Redrix, paste ./install.sh --dry-run <id> and ./verify.sh <id>. Firmware, distribution, GNOME and kernel versions. -->

## Checklist

- [ ] `tests/run.sh` passes and `shellcheck -x` is clean
- [ ] Install is idempotent, honours `--dry-run`, and uninstall restores what was there before
- [ ] `CHANGES`, `ROLLBACK` and `docs/components/<id>.md` describe what really happens
- [ ] A new download is pinned (full commit or sha256) and listed in `NOTICE.md`; `CHANGELOG.md` is updated
- [ ] Code, comments and messages are in English; no language or locale is hard-coded
- [ ] Nothing specific to my machine (user, UUIDs, serials, paths); no source file over 500 lines
- [ ] I fixed the cause, not the symptom
