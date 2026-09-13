# TODO.AI.md

## Pre-existing `script-lint` violations found 2026-09-13 (centos->rhel rename sweep)

Surfaced incidentally while updating hardcoded `casjay-base/centos`/
`pkmgr/centos` URLs to `casjay-base/rhel`/`pkmgr/rhel` — confirmed via
`git diff` that these predate this edit (only the URL lines changed).
Re-run `script-lint` for exact current line numbers before fixing.

- [ ] scripts/development.sh, scripts/template: grep calls missing
      `--` before the query pattern; naming/other convention violations
