# shell-commands

Proof-of-concept repository demonstrating how to structure complex command hierarchies in pure Bash.

## Commands

- `./super --help` — show usage and list all sub-commands (descriptions loaded dynamically by sourcing each).
- `./super <subcmd> --help` or `./super <subcmd> -h` — show help for one sub-command.
- `./super -d <subcmd> ...` — enable debug logging (sets `DEBUG=true`).

There is no package manager, install, or build step; run the scripts directly after ensuring they are executable.

## Modules

- `commands/` — One file per sub-command. File name (no extension) becomes the sub-command name. Must be executable.
- `libs/` — Shared Bash libraries. Root sources `libs/common`; sub-commands inherit the functions. Use `::` namespacing (e.g. `common::log_info`).

## Workflows

### Adding a new sub-command

The root dispatcher and `--help` machinery depend on strict conventions. Follow all steps.

1. Create a new file `commands/<name>` with no suffix (e.g. `commands/status`).
2. Make it executable: `chmod +x commands/<name>`.
3. Add the shebang as the very first line: `#!/usr/bin/env bash`.
4. Define exactly these three functions (names must match the file basename):
   - `<name>_describe()` — returns a one-line summary (called by root `--help`).
   - `<name>_show_help()` — prints usage, options, and exits.
   - `<name>_run() { ... }` — parses remaining args (usually with `getopt`) and executes.
5. Inside the functions, rely on globals set by root: `$script_name`, `$DEBUG`. Call library helpers via the `::` namespace.
6. For argument parsing, follow the `getopt` pattern used in `commands/hello` and `commands/bye`.
7. Verify:
   - `./super --help` lists the new command with its describe text.
   - `./super <name> --help` shows its help.
   - `./super <name> ...` executes `_run`.
   - `./test/run` (or the relevant new tests) still passes.

## Testing

- `./test/run` — run the full suite (thin wrapper around `bats test/`).
- Requires `bats-core`. On macOS also `gnu-getopt` (the scripts use GNU-style long options):
  ```bash
  brew install bats-core gnu-getopt
  ```
- Tests live in `test/`:
  - `test_helper.bash` — per-test isolated `$HOME`, dummy `~/.bash_env`, `PROJECT_ROOT`/`SUPER` discovery, `run_super()` helper (auto-injects GNU getopt on mac when present), `strip_ansi()`, `get_log_file()`.
  - `cli.bats` — black-box coverage of dispatcher, dynamic help (describe()), all current sub-commands, `-d`/`-c` flags, error paths, and the mandatory log-file side-effect.
- Isolation is mandatory: `super` and `common::load_config` refuse to run without a config file and always append to `$HOME/.$script_name.log`. The helper creates a fresh temp dir for `HOME`/`CONFIG_FILE` on every `@test`.
- When adding a new sub-command (see workflow above), also add or extend tests so `./test/run` passes. The dynamic `--help` test will automatically exercise your `_describe()`.

**Note on macOS / getopt:** Stock `/usr/bin/getopt` is BSD and will cause "Error: Incorrect options provided" or silent mis-parsing for any sub-command using `--long` flags (hello and bye both do). The test helper + `./test/run` will use the Homebrew GNU version when available. Document the same requirement for manual use of the CLI.

## Code templates

### New sub-command skeleton

```bash
#!/usr/bin/env bash

status_describe() {
    echo "Show current status."
}

status_show_help() {
    echo "Usage: $script_name status [OPTIONS]"
    echo "Show current status."
    echo ""
    echo "Optional flags:"
    echo "  -h, --help  Show this help message"
}

status_run() {
    common::log_debug "Executed sub-command status with arguments $@"

    # Using getopt for parsing (pattern from commands/hello)
    TEMP=$(getopt -o dh --long display-time,help -- "$@")
    if [ $? != 0 ]; then
        echo "Error: Incorrect options provided"
        exit 1
    fi
    eval set -- "$TEMP"

    # ... then case "$1" in -d|--display-time) ... ; --) shift; break ;; esac

    echo "Status: OK"
}
```

### Library call (from any command or root)

```bash
common::log_info "Task started"
common::log_warn "Deprecated flag used"
common::log_error "Something failed"
common::log_debug "Detailed info only when DEBUG=true"
```

## Gotchas

- **describe() runs during root `--help` for every command.** The `_show_help` function in `super` sources *all* files in `commands/` and invokes `<name>_describe`. Keep top-level code and describe() side-effect free.
- **No explicit variable passing to sub-commands.** After `source "$SUB_COMMANDS_DIR/$cmd"`, the `_run` function executes in the same shell scope. `$cmd` (local in `_dispatch`), `$script_name`, `$DEBUG`, and `$CONFIG_FILE` are visible. Avoid re-declaring them as `local` if you need the root values.
- **Config file is sourced unconditionally before dispatch.** `common::load_config "$CONFIG_FILE"` (default `~/.bash_env`) happens for every invocation. Sub-commands can assume variables from it are available.
- **Log file is written on every run.** `common::log_to_file` is called at the very start of `super` before option parsing.

## Do / don't

- **Do not** give command files any extension (`.sh`, `.bash`, etc.).
  **Do** use bare names that match the desired sub-command (e.g. `commands/bye`, `commands/hello`).
- **Do not** skip implementing any of the three required functions.
  **Do** provide `<name>_describe`, `<name>_show_help`, and `<name>_run` in every command file.
- **Do not** invoke a sub-command script directly with `bash` or by path.
  **Do** always go through the root `super` script so that sourcing, globals, logging, and config loading occur.
- **Do not** prefix the three public entrypoint functions with `_`.
  **Do** use a leading `_` only for private helper functions inside a command file (per project recommendation).

## References

- [README.md](README.md) — read for the original design rationale and high-level testing instructions.
- `test/test_helper.bash` and `test/cli.bats` — the executable documentation of current behavior and test patterns.
