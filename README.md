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
git clone https://github.com/wallach-game/bashstuff.git
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

## Testing

The repo ships a small bash test suite under [`test/`](./test/). Run it with:

```bash
bash test/run.sh
```

Each `test_*.sh` file uses the assertion helpers in `test/lib.sh` and exits
non-zero on failure. The runner aggregates results and the same script is what
GitHub Actions runs on every pull request — see
[`.github/workflows/test.yml`](./.github/workflows/test.yml).

You can also run the end-to-end demo directly:

```bash
bash example.sh
```

Set `DEBUG=1` to keep the runtime directory after the script exits and inspect
the files:

```bash
DEBUG=1 bash example.sh
```

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

## Methods on objects

`methods.sh` adds a tiny dispatcher so objects can have functions, without
giving up the function-only-on-load discipline.

The convention is dead simple — a method `m` on type `t` is just a Bash
function named `t_m`, and the first argument is always the object id:

```bash
require "object"  "file://$PWD/object.sh"
require "methods" "file://$PWD/methods.sh"
source ./examples/user.sh

user_create alice "Alice" "alice@example.com"

obj_call user alice greet            # Hello, Alice!
obj_call user alice set_email new@x  # mutate via dispatch
obj_call user alice describe         # multi-line summary

obj_methods user                     # list every method on this type
obj_method_exists user greet && echo yep
```

| Function | Purpose |
| --- | --- |
| `obj_call <type> <id> <method> [args…]` | look up `<type>_<method>` and call it with the id + args |
| `obj_method_exists <type> <method>` | exit 0 if the dispatcher would resolve it |
| `obj_methods <type>` | print every defined method on this type |

`obj_call` refuses to dispatch to a missing object or an unknown method, and
prints a clear error to stderr in both cases.  Constructors (`<type>_create`,
…) are called *directly* — they create the object, so the existence check
would block them.

A complete demo lives in [`examples/methods_demo.sh`](./examples/methods_demo.sh).

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
