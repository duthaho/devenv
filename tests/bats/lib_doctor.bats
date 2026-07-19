#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

# Source lib/doctor.sh in a controlled subshell with env overrides.
# Usage: dsh '<extra env>' '<function call>'
dsh() {
  local env="$1" call="$2"
  bash -c "$env source '$DEVENV_ROOT/lib/doctor.sh' && $call"
}

# --- os check -------------------------------------------------------------

@test "devenv_dcheck_os returns PASS and names the host os" {
  run dsh "OSTYPE=darwin23;" "devenv_dcheck_os"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
  [[ "$output" == *"os"* ]]
  [[ "$output" == *"mac"* ]]
}

@test "devenv_dcheck_os includes distro on linux" {
  mkdir -p "$TEST_TMP/etc"
  echo 'ID=ubuntu' > "$TEST_TMP/etc/os-release"
  run dsh "OSTYPE=linux-gnu; DEVENV_ETC=$TEST_TMP/etc; DEVENV_PROC=$TEST_TMP/noexist;" "devenv_dcheck_os"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linux/ubuntu"* ]]
}

# --- aggregator -----------------------------------------------------------

@test "devenv_doctor_env prints an os line and returns 0 when no check FAILs" {
  # Deterministic: mise/shims on PATH (shims PASS), OP_MOCK=1 (op PASS); any
  # WARNs (shell-hooks, ssh-agent) must not affect the exit result.
  # Use /usr/bin (not the host $PATH, whose entries contain spaces on Windows
  # git-bash and would break the inline `bash -c` env string).
  run dsh "OSTYPE=darwin23; PATH=$TEST_TMP/x/mise/shims:/usr/bin; OP_MOCK=1; unset SSH_AUTH_SOCK;" "devenv_doctor_env"
  [ "$status" -eq 0 ]
  [[ "$output" == *"os"* ]]
  [[ "$output" == *"PASS"* ]]
}

# --- op check -------------------------------------------------------------

@test "devenv_dcheck_op FAILs when op is not installed" {
  mkdir -p "$TEST_TMP/empty"
  run dsh "PATH=$TEST_TMP/empty; OSTYPE=linux-gnu; DEVENV_PROC=/nope; OP_MOCK=0;" "devenv_dcheck_op"
  [ "$status" -eq 1 ]
  [[ "$output" == FAIL* ]]
  [[ "$output" == *"MISSING"* ]]
}

@test "devenv_dcheck_op PASSes under OP_MOCK=1" {
  mkdir -p "$TEST_TMP/empty"
  run dsh "PATH=$TEST_TMP/empty; OSTYPE=linux-gnu; DEVENV_PROC=/nope; OP_MOCK=1;" "devenv_dcheck_op"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "devenv_dcheck_op WARNs on not-signed-in on linux" {
  stub_cmd op 'exit 1'   # op whoami fails => not signed in
  run dsh "OSTYPE=linux-gnu; DEVENV_PROC=/nope; OP_MOCK=0;" "devenv_dcheck_op"
  [ "$status" -eq 2 ]
  [[ "$output" == WARN* ]]
  [[ "$output" == *"not-signed-in"* ]]
}

@test "devenv_dcheck_op FAILs on not-signed-in on mac" {
  stub_cmd op 'exit 1'
  run dsh "OSTYPE=darwin23; OP_MOCK=0;" "devenv_dcheck_op"
  [ "$status" -eq 1 ]
  [[ "$output" == FAIL* ]]
}

# --- ssh-agent check ------------------------------------------------------

@test "devenv_dcheck_ssh_agent PASSes when SSH_AUTH_SOCK is a live socket" {
  case "$OSTYPE" in
    msys*|cygwin*|win32*) skip "AF_UNIX sockets aren't recognized by test -S under MSYS" ;;
  esac
  command -v python3 >/dev/null 2>&1 || skip "python3 not available to create a unix socket"
  python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$TEST_TMP/agent.sock"
  [ -S "$TEST_TMP/agent.sock" ]
  run dsh "OSTYPE=linux-gnu; DEVENV_PROC=/nope; SSH_AUTH_SOCK=$TEST_TMP/agent.sock;" "devenv_dcheck_ssh_agent"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "devenv_dcheck_ssh_agent WARNs when SSH_AUTH_SOCK is unset" {
  run dsh "OSTYPE=linux-gnu; DEVENV_PROC=/nope; unset SSH_AUTH_SOCK;" "devenv_dcheck_ssh_agent"
  [ "$status" -eq 2 ]
  [[ "$output" == WARN* ]]
}

# --- shell-hooks check ----------------------------------------------------

@test "devenv_dcheck_shell_hooks PASSes when both hooks present" {
  mkdir -p "$TEST_TMP/h"
  printf 'eval "$(mise activate bash)"\neval "$(direnv hook bash)"\n' > "$TEST_TMP/h/.bashrc"
  run dsh "HOME=$TEST_TMP/h;" "devenv_dcheck_shell_hooks"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "devenv_dcheck_shell_hooks WARNs when no rc files present" {
  mkdir -p "$TEST_TMP/h"
  run dsh "HOME=$TEST_TMP/h;" "devenv_dcheck_shell_hooks"
  [ "$status" -eq 2 ]
  [[ "$output" == WARN* ]]
}

@test "devenv_dcheck_shell_hooks WARN names the missing hook (partial config)" {
  mkdir -p "$TEST_TMP/h"
  printf 'eval "$(mise activate bash)"\n' > "$TEST_TMP/h/.bashrc"
  run dsh "HOME=$TEST_TMP/h;" "devenv_dcheck_shell_hooks"
  [ "$status" -eq 2 ]
  [[ "$output" == *"direnv"* ]]
  [[ "$output" != *"mise+direnv wired"* ]]
}

# --- shims check ----------------------------------------------------------

@test "devenv_dcheck_shims PASSes when mise/shims is on PATH" {
  run dsh "PATH=$TEST_TMP/x/mise/shims:$TEST_TMP/empty;" "devenv_dcheck_shims"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "devenv_dcheck_shims WARNs when mise present but shims not on PATH" {
  stub_cmd mise 'exit 0'   # mise resolvable via hook path
  run dsh "" "devenv_dcheck_shims"
  [ "$status" -eq 2 ]
  [[ "$output" == WARN* ]]
}

@test "devenv_dcheck_shims FAILs when mise is not resolvable at all" {
  mkdir -p "$TEST_TMP/empty"
  run dsh "PATH=$TEST_TMP/empty;" "devenv_dcheck_shims"
  [ "$status" -eq 1 ]
  [[ "$output" == FAIL* ]]
}

# --- interop check (WSL only) ---------------------------------------------

wsl_env() {
  mkdir -p "$TEST_TMP/proc"
  echo 'Linux version 5.15 (microsoft@WSL)' > "$TEST_TMP/proc/version"
  echo "OSTYPE=linux-gnu; DEVENV_PROC=$TEST_TMP/proc;"
}

@test "devenv_dcheck_interop PASSes on WSL when cmd.exe is reachable" {
  stub_cmd cmd.exe 'exit 0'
  run dsh "$(wsl_env)" "devenv_dcheck_interop"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
  [[ "$output" == *"interop"* ]]
}

@test "devenv_dcheck_interop WARNs on WSL when no windows interop on PATH" {
  # Constrain PATH to /usr/bin: it has grep (needed for WSL detection) but not
  # cmd.exe/powershell.exe — on Windows git-bash the host PATH *does* carry
  # those, which would otherwise flip this to PASS.
  run dsh "$(wsl_env) PATH=/usr/bin;" "devenv_dcheck_interop"
  [ "$status" -eq 2 ]
  [[ "$output" == WARN* ]]
}

@test "devenv_dcheck_interop emits nothing off WSL" {
  run dsh "OSTYPE=darwin23;" "devenv_dcheck_interop"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- aggregator FAIL propagation ------------------------------------------

@test "devenv_doctor_env returns 1 when a check FAILs (shims)" {
  mkdir -p "$TEST_TMP/empty"
  run dsh "OSTYPE=linux-gnu; DEVENV_PROC=/nope; PATH=$TEST_TMP/empty; OP_MOCK=1; unset SSH_AUTH_SOCK;" "devenv_doctor_env"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" == *"shims"* ]]
}

@test "devenv_doctor_env prints checks in the spec order" {
  run dsh "$(wsl_env) OP_MOCK=1;" "devenv_doctor_env"
  # os first, ssh-agent last; interop present (WSL)
  [[ "$output" == *"os"*"interop"*"shell-hooks"*"shims"*"op"*"ssh-agent"* ]]
}
