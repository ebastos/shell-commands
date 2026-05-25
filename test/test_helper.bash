#!/usr/bin/env bash
# test/test_helper.bash
# Common setup, teardown, and helpers for bats tests.
# This isolates tests from the user's real $HOME, config, and logs.

# shellcheck shell=bash

setup() {
  # Per-test isolated HOME so logs and config don't leak or conflict.
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  # Provide the config file that super + common::load_config require by default.
  export CONFIG_FILE="$HOME/.bash_env"
  cat >"$CONFIG_FILE" <<'EOF'
# Minimal fake environment for shell-commands tests.
# In real use this would contain user variables; here we just need the file to exist.
TEST_MODE="true"
DUMMY_VAR="dummy_value"
EOF

  # Locate the project root and the super entrypoint (robust from any cwd).
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export PROJECT_ROOT
  export SUPER="$PROJECT_ROOT/super"

  # Ensure the script under test is executable (defensive; repo should already have +x).
  chmod +x "$SUPER" "$PROJECT_ROOT"/commands/* 2>/dev/null || true
}

teardown() {
  # Clean up the isolated home to keep /tmp tidy.
  if [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
}

# Return the path to GNU getopt (via Homebrew on macOS) if it is installed.
# The existing command scripts use GNU-style getopt with --long options.
# Stock macOS /usr/bin/getopt is BSD getopt and does not support --long the same way.
_get_gnu_getopt_path() {
  if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    local prefix
    prefix="$(brew --prefix gnu-getopt 2>/dev/null || true)"
    if [[ -n "$prefix" && -x "$prefix/bin/getopt" ]]; then
      echo "$prefix/bin"
      return 0
    fi
  fi
  # On Linux or when already using GNU getopt in PATH, nothing to prepend.
  return 1
}

# Run the super CLI with correct environment for the test.
# Automatically injects GNU getopt into PATH on macOS when available via brew.
# Usage (in a @test):
#   run_super --help
#   [ "$status" -eq 0 ]
#   [[ "$output" == *"Available sub-commands:"* ]]
#
# After invocation, the standard bats run variables are populated:
#   $status, $output, $lines[@]
run_super() {
  local getopt_dir
  getopt_dir="$(_get_gnu_getopt_path || true)"

  if [[ -n "$getopt_dir" ]]; then
    PATH="$getopt_dir:$PATH" run "$SUPER" "$@"
  else
    run "$SUPER" "$@"
  fi
}

# Strip ANSI color escape codes from a string (for assertions on colored output).
# Example:
#   clean="$(strip_ansi "$output")"
#   [[ "$clean" == *"[INFO]: something"* ]]
strip_ansi() {
  # Handles common SGR and some other sequences.
  sed -E 's/\x1b\[[0-9;]*[mGK]//g' <<<"$*"
}

# Convenience: path to the log file that super always writes (per invocation).
get_log_file() {
  echo "$HOME/.super.log"
}
