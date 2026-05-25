#!/usr/bin/env bats
# test/cli.bats
# Integration tests for the super CLI dispatcher and sub-commands.
# Run with: bats test/
#
# These tests exercise the full public surface:
#   - root help (dynamic sub-command discovery via describe())
#   - per-subcommand help
#   - successful dispatch and argument passing
#   - flag handling (including debug)
#   - error cases (missing config, bad command, no subcommand)
#   - side effects (log file written on every invocation)
#
# See test_helper.bash for isolation strategy (fresh $HOME + config per test).

load "test_helper"

# -----------------------------------------------------------------------------
# Basic dispatcher behavior
# -----------------------------------------------------------------------------

@test "no sub-command prints usage error and exits 1" {
  run_super
  [ "$status" -eq 1 ]
  [[ "$output" == *"No sub-command provided."* ]]
  [[ "$output" == *"Run 'super --help' for usage information."* ]]
}

@test "invalid sub-command prints error and exits 1" {
  run_super nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid command: nonexistent"* ]]
}

# -----------------------------------------------------------------------------
# Root --help (dynamic loading of descriptions)
# -----------------------------------------------------------------------------

@test "root --help lists all sub-commands with their describe text" {
  run_super --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: super [SUB-COMMAND] [OPTIONS]"* ]]
  [[ "$output" == *"Available sub-commands:"* ]]
  # Descriptions are loaded dynamically; match loosely to avoid whitespace/column fragility
  # from the printf "%-20s %s\n" formatting in super.
  [[ "$output" == *"hello"* && "$output" == *"Greet a user by name."* ]]
  [[ "$output" == *"bye"* && "$output" == *"Exit the program."* ]]
  [[ "$output" == *"Run 'super [SUB-COMMAND] --help' for more information"* ]]
}

@test "root -h also shows help" {
  run_super -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Available sub-commands:"* ]]
}

# -----------------------------------------------------------------------------
# hello sub-command
# -----------------------------------------------------------------------------

@test "hello --help shows its own usage" {
  run_super hello --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: super hello [OPTIONS] [NAME]"* ]]
  [[ "$output" == *"Say hello to NAME, or to 'World' if NAME is not provided."* ]]
  [[ "$output" == *"-d, --display-time"* ]]
}

@test "hello with no args greets World" {
  run_super hello
  [ "$status" -eq 0 ]
  [[ "$output" == "Hello, World!" ]]
}

@test "hello with a name argument greets that name" {
  run_super hello Alice
  [ "$status" -eq 0 ]
  [[ "$output" == "Hello, Alice!" ]]
}

@test "hello with multiple name args uses all of them" {
  run_super hello Bob "and Carol"
  [ "$status" -eq 0 ]
  [[ "$output" == "Hello, Bob and Carol!" ]]
}

@test "hello -d shows the time" {
  # Short option only (works with both BSD and GNU getopt).
  run_super hello -d
  [ "$status" -eq 0 ]
  [[ "$output" == "Hello, World! It is "* ]]
}

# -----------------------------------------------------------------------------
# bye sub-command
# -----------------------------------------------------------------------------

@test "bye runs and prints stopping message" {
  run_super bye
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopping the program..."* ]]
}

@test "bye -h shows its help (short flag)" {
  run_super bye -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: super bye [OPTIONS]"* ]]
  [[ "$output" == *"Exit the program."* ]]
}

# -----------------------------------------------------------------------------
# Debug flag (-d at root) and propagation
# -----------------------------------------------------------------------------

@test "-d sets DEBUG and enables debug logging in sub-commands" {
  run_super -d hello
  [ "$status" -eq 0 ]
  # The hello sub-command emits a debug line via common::log_debug when DEBUG=true.
  # Use strip_ansi because log_debug outputs ANSI-colored text.
  clean="$(strip_ansi "$output")"
  [[ "$clean" == *"[DEBUG]: Executed sub-command hello with arguments"* ]]
  # Normal (non-debug) output is still present
  [[ "$output" == *"Hello, World!"* ]]
}

# -----------------------------------------------------------------------------
# Config file handling (via -c and load_config)
# -----------------------------------------------------------------------------

@test "-c with nonexistent config file fails early with clear error" {
  run_super -c /tmp/does-not-exist-$$.env hello
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Config file not found at /tmp/does-not-exist-"* ]]
}

# -----------------------------------------------------------------------------
# Logging side-effect (always happens)
# -----------------------------------------------------------------------------

@test "every invocation appends an entry to the log file" {
  local log
  log="$(get_log_file)"

  run_super hello TestUser
  [ "$status" -eq 0 ]

  [ -f "$log" ]
  # Log contains timestamped invocation record (format: [YYYY-MM-DD HH:MM:SS] super hello TestUser)
  grep -q "super hello TestUser" "$log"
}

@test "log file location follows script_name (derived from basename of super)" {
  local log
  log="$(get_log_file)"
  # When we invoke the script (even via full path), script_name=super
  [[ "$log" == *"/.super.log" ]]
}

# -----------------------------------------------------------------------------
# Sanity: library is loadable and basic functions exist (white-box spot-check)
# -----------------------------------------------------------------------------

@test "libs/common can be sourced and exposes the :: namespaced helpers" {
  # Source exactly as the real super does.
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/libs/common"

  # These are just function declarations; invoking most produces output or exits.
  # We only assert they are defined.
  type common::log_info >/dev/null
  type common::log_debug >/dev/null
  type common::load_config >/dev/null
  type common::log_to_file >/dev/null
}
