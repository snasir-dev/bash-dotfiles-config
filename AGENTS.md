# AGENTS.md

The project instruction file for this repository, read by every coding agent. Claude Code
reads CLAUDE.md instead, which imports this file.

## What this is

A modular Bash dotfiles/configuration repo for **Windows Git Bash** (not Linux/WSL). It replaces a monolithic `~/.bashrc` with a tree of small, single-purpose files that get auto-sourced in a defined order, plus a convention for dropping in standalone scripts that become instantly runnable and discoverable with zero registration.

## Common commands

There is no build step, package manager, or test suite. "Running" this project means sourcing it into a live shell.

- **Reload the shell after any change**: `src` / `reload` / `refresh` / `r` / `R` (all aliases for `reload_shell`, defined in `aliases/aliases.sh`) — re-sources `~/.bashrc`, which re-runs the whole bootstrap chain below. This is the primary way to verify a change works.
  - `reload_shell` defaults to verbose (`DEBUG=true`), printing a `Sourcing [label (folder/file)]: path` line for every file loaded. Pass `false` / `-s` / `--silent` / `-q` / `--quiet` to silence it: `reload_shell -s`.
- **First-time install on a machine**: `./setup_bash.sh` from the repo root — backs up any existing `~/.bashrc`/`~/.bash_profile` to a timestamped folder, symlinks them to this repo's `config/setup/` copies, and creates `~/.bash_local` if missing.
- **Run/find a standalone script**: type `scripts`, `x`, or `X` to fuzzy-pick and run any script under `BASH_SCRIPTS/` via `fzf` (see `x-script-selector.sh`), or call it directly by filename — `BASH_SCRIPTS/` is on `PATH`.
- **Formatting**: `.editorconfig` encodes `shfmt` conventions for this repo — LF line endings, 4-space indent, `bash` variant, `binary_next_line`, `switch_case_indent`, `space_redirects`, `simplify_binary`. Match these by hand if `shfmt` isn't run.
- **Linting**: no CI/config file, but existing code uses `# shellcheck disable=SC____` inline comments where a warning is intentionally suppressed — follow that pattern rather than removing checks silently.

## Architecture: the bootstrap chain

Everything hinges on one env var, `$BASH_DIR`, and one entry-point script, `main.sh`.

1. `~/.bashrc` on the machine is a **symlink** to `config/setup/.bashrc` in this repo (created by `setup_bash.sh`). Editing either path edits the same file.
2. `config/setup/.bashrc` sets `export BASH_DIR="$HOME/.config/bash"` — the single source of truth for where this repo lives on disk — then does `source "$BASH_DIR/main.sh"`. If the repo's install location ever changes, that file's header comment says to update it in **3 places**: `.bashrc`, `.bash_profile`, and `BASH_REPO_DIR` in `setup_bash.sh` (plus the README).
3. `main.sh` defines `source_sh_files(label, dir)`: it recursively finds every `*.sh` under a directory and `source`s each one, skipping anything listed in its `EXCLUDE_FILES` / `EXCLUDE_DIRS` / `EXCLUDE_FILES_BY_DIR` (per-folder) arrays. It then calls this helper in a **fixed, load-bearing order**:

   ```
   config → env → functions → aliases → completions → (theme, sourced directly) → tools
   ```

   `functions` must load before `aliases` because some aliases call functions defined there. After the sweep, `main.sh` also:
   - `export PATH="$BASH_DIR/BASH_SCRIPTS:$PATH"` — makes every script in `BASH_SCRIPTS/` runnable by filename.
   - Sources `~/.bash_local` if present — gitignored, machine-specific overrides/secrets, never committed.
   - Sources `config/themes/oh-my-posh/setup_oh_my_posh.sh` directly (not part of the generic sweep) and warns if it's missing.

## Directory map (what goes where)

Each top-level directory has exactly one job; keep that separation when adding things.

| Directory | Purpose | Add new... |
|---|---|---|
| `env/` | `env.sh` (exported vars: `XDG_CONFIG_HOME`, `EDITOR`, `KUBECONFIG`, quick-jump path vars like `$devops`, `$k8s`), `path.sh` (PATH entries for Windows `.exe` tools via `cygpath`) | env vars → `env.sh`; PATH entries → `path.sh` |
| `functions/` | Reusable shell functions, one file per concern (`filepaths.sh`, `filetree.sh`, `symlinks.sh`, `copy.sh`, `directory_traversal_functions.sh`, `_general-functions.sh`) | new function in the matching file, or a new file |
| `aliases/aliases.sh` | All aliases, grouped in comment-delimited sections; also `reload_shell()` | new alias under the right section |
| `completions/` | `completions.sh` + `packages/` (vendored completion scripts, e.g. `eza.bash`) | new completion script |
| `tools/` | One `.sh` per CLI tool's config/aliases/wrappers, grouped by category (`development/`, `file-management/`, `shell-utility-and-system/`, `text/…`) | `tools/<category>/<tool>.sh`; new category if none fits (see `tools/_placeholder/template`) |
| `config/` | `bash_keybinds.sh`, `setup/` (the real `.bashrc`/`.bash_profile` targets), `themes/oh-my-posh/` | — |
| `BASH_SCRIPTS/` | Standalone executable scripts (see below) | `x-<kebab-case>.sh`, anywhere under this tree |
| `.bash_local` | Gitignored, machine-specific overrides/secrets | — |

To exclude a file/folder from `main.sh`'s auto-sourcing sweep, add it to the `EXCLUDE_FILES` / `EXCLUDE_DIRS` / `EXCLUDE_FILES_BY_DIR` arrays inside `source_sh_files` in `main.sh`.

## The `BASH_SCRIPTS/` convention

This is the "easy way to create/launch/find scripts" the repo is built around:

- Scripts live under `BASH_SCRIPTS/` (optionally in a category subfolder, e.g. `git_scripts/`, `kubernetes/`), named `x-<kebab-case-name>.sh`, and are made executable.
- Each script typically wraps its logic in a same-named function and invokes it at the bottom with `"$@"` (see `x-create-symlinks.sh`, `x-test-script.sh`).
- **No registration step is needed anywhere else.** `BASH_SCRIPTS/` is added to `PATH` by `main.sh`, so the script is immediately callable by filename, and `x-script-selector.sh` (aliased to `scripts` / `x` / `X`) uses `fd` + `fzf` to fuzzy-find and run any `.sh` under `BASH_SCRIPTS/` on the fly (results sorted so shallower scripts rank first; the selector excludes itself).
- **Scripts do not get `.bashrc` sourced into them.** Bash only sources `.bashrc` for interactive shells, so a script run standalone only inherits *exported* vars/functions from the parent shell — nothing else. Consequences:
  - Functions a script needs must be `export -f`'d (see the bottom of `functions/_general-functions.sh`) or the script must `source "$BASH_DIR/path/to/file.sh"` itself directly (see the header of `x-create-symlinks.sh`, which sources `tools/file-management/fzf.sh` explicitly).
  - `x-test-script.sh` demonstrates/verifies this boundary — useful as a reference when debugging "why isn't my function/alias available in this script".

## Windows-specific notes

- `env/env.sh` sets `MSYS="winsymlinks:nativestrict"` so `ln -s` produces real native Windows symlinks (matching what `mklink`/`New-Item` create), instead of the default MSYS symlink emulation.
- `cygpath` is used throughout to convert between Windows and Unix path styles (e.g. `env/path.sh` for locating `.exe` install dirs under `$LOCALAPPDATA`, `x-create-symlinks.sh` for resolving/display paths).
