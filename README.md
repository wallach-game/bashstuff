# Bash Runtime Extension

A tiny runtime primitive for Bash: a `require()`-style module loader and a
file-per-object storage package, both backed by `/dev/shm` so they live in RAM
and disappear when the script exits.

No Node, no Python, no daemon. Just `bash`, `curl`, and `flock`.

## Why

Bash scripts that grow past a few hundred lines start wanting two things they
don't have: a way to pull in shared code by URL, and a way to keep small
amounts of structured state without reaching for SQLite or jq. This repo
provides both, in under 150 lines, with no install step.

## Install

Clone the repo or vendor `core.sh` and `object.sh` into your project:

```bash
git clone https://github.com/<you>/bashstuff.git
```

Requirements: `bash` 4+, `curl`, `flock`.

## Quick start

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="myapp"
source ./core.sh

require "object" "file://$PWD/object.sh"

obj_put user 123 '{"name":"alice"}'
obj_get user 123             # -> {"name":"alice"}
obj_exists user 123 && echo "yes"
obj_del user 123
```

A runnable end-to-end demo lives in [`example.sh`](./example.sh).

## How it works

### Runtime directory

`core.sh` carves out an isolated workspace per script run:

```
/dev/shm/<app>_<epoch>_<pid>/
  deps/      # cached modules
  objects/   # object storage
  locks/     # flock files
  tmp/
```

The directory is removed on `EXIT` unless `DEBUG=1` is set.

### `require <name> <url>`

Downloads the module if missing, resolves any `# @dep` headers it declares,
then sources it. Dependency declarations look like:

```bash
# @dep log https://example.com/log.sh
# @dep fs  https://example.com/fs.sh
```

`curl` handles `file://` URLs natively, so local modules work without hosting.

### Object storage

Each object lives at `objects/<type>/<id>/` with separate `data` and `meta`
files. The API is small on purpose:

| Function | Purpose |
| --- | --- |
| `obj_put <type> <id> <data>` | create or overwrite |
| `obj_get <type> <id>` | print payload, if it exists |
| `obj_del <type> <id>` | remove |
| `obj_exists <type> <id>` | exit 0 if present |
| `obj_lock <type> <id> <cmd…>` | run `<cmd>` under `flock` |

## Design rules

* Modules define functions only — no work on load.
* Modules are idempotent (safe to source more than once).
* All paths derive from `$RUNTIME_DIR`.
* Globals are prefixed (`obj_`, `require_`, …).
* No external runtime beyond `bash` / `curl` / `flock`.

## Status

This is a runtime primitive, not a database. There is no version solver, no
circular-dep detection, no query layer, and no on-disk persistence. See
[`notes.md`](./notes.md) for the original design doc and the list of planned
extensions (indexing, querying, TTL, snapshots).

## License

MIT.
