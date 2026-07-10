#!/bin/bash

# Root init orchestration regression tests. All execution happens in a fake
# repository; the real dotfiles modules and HOME are never changed.

set -u

TMP_BASE="${TMPDIR:-/tmp}"
TEST_ROOT="$(mktemp -d "${TMP_BASE%/}/dotfiles-init-tests.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL  %s\n' "$1" >&2
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
    printf '  expected:\n%s\n  actual:\n%s\n' "$expected" "$actual" >&2
  fi
}

make_fake_repo() {
  local name="$1"
  local repo="$TEST_ROOT/$name"
  local module
  local module_dir

  mkdir -p "$repo"
  cp "$(cd "$(dirname "$0")/../.." && pwd)/init.sh" "$repo/init.sh"

  for module in bin zsh bash agents claude ssh tmux .config .config/karabiner; do
    module_dir="$repo/$module"
    mkdir -p "$module_dir"
    cat > "$module_dir/init.sh" <<EOF
#!/bin/bash
printf '%s\\n' '$module' >> "\$TEST_LOG"
if [[ "\${FAIL_MODULE:-}" == '$module' ]]; then
  exit 23
fi
EOF
    chmod +x "$module_dir/init.sh"
  done

  mkdir -p "$repo/foo"
  cat > "$repo/foo/init.sh" <<'EOF'
#!/bin/bash
printf '%s\n' 'foo' >> "$TEST_LOG"
EOF
  chmod +x "$repo/foo/init.sh"

  printf '%s\n' "$repo"
}

make_uname_stub() {
  local name="$1"
  local platform="$2"
  local bin_dir="$TEST_ROOT/$name-bin"

  mkdir -p "$bin_dir"
  cat > "$bin_dir/uname" <<EOF
#!/bin/bash
printf '%s\\n' '$platform'
EOF
  chmod +x "$bin_dir/uname"
  printf '%s\n' "$bin_dir"
}

expected_common_order() {
  cat <<'EOF'
bin
zsh
bash
agents
claude
ssh
tmux
.config
EOF
}

test_exact_order_and_ignores_extra() {
  local repo
  local fake_bin
  local log="$TEST_ROOT/order.log"
  local actual

  repo="$(make_fake_repo order)"
  fake_bin="$(make_uname_stub order Linux)"
  TEST_LOG="$log" PATH="$fake_bin:$PATH" bash "$repo/init.sh" >/dev/null
  actual="$(cat "$log")"
  assert_equal "$(expected_common_order)" "$actual" \
    "fixed modules run exactly once in order; extra modules are ignored"
}

test_failure_stops_later_modules() {
  local repo
  local fake_bin
  local log="$TEST_ROOT/failure.log"
  local actual
  local status=0

  repo="$(make_fake_repo failure)"
  fake_bin="$(make_uname_stub failure Linux)"
  TEST_LOG="$log" FAIL_MODULE="claude" PATH="$fake_bin:$PATH" \
    bash "$repo/init.sh" >/dev/null 2>&1 || status=$?
  actual="$(cat "$log")"

  if [[ "$status" -eq 23 ]]; then
    pass "module failure status is preserved"
  else
    fail "module failure status is preserved"
  fi
  assert_equal $'bin\nzsh\nbash\nagents\nclaude' "$actual" \
    "module failure stops all later modules"
}

test_list_is_read_only() {
  local repo
  local fake_bin
  local log="$TEST_ROOT/list.log"
  local actual
  local expected

  repo="$(make_fake_repo list)"
  fake_bin="$(make_uname_stub list Linux)"
  actual="$(TEST_LOG="$log" PATH="$fake_bin:$PATH" bash "$repo/init.sh" --list)"
  expected="$(printf '%s\n' \
    "$repo/bin/init.sh" \
    "$repo/zsh/init.sh" \
    "$repo/bash/init.sh" \
    "$repo/agents/init.sh" \
    "$repo/claude/init.sh" \
    "$repo/ssh/init.sh" \
    "$repo/tmux/init.sh" \
    "$repo/.config/init.sh")"

  assert_equal "$expected" "$actual" "--list prints resolved Linux module order"
  if [[ ! -e "$log" ]]; then
    pass "--list executes no modules"
  else
    fail "--list executes no modules"
  fi
}

test_platform_karabiner_boundary() {
  local repo
  local darwin_bin
  local linux_bin
  local darwin_log="$TEST_ROOT/darwin.log"
  local linux_log="$TEST_ROOT/linux.log"
  local darwin_actual
  local linux_actual
  local darwin_expected

  repo="$(make_fake_repo platforms)"
  darwin_bin="$(make_uname_stub darwin Darwin)"
  linux_bin="$(make_uname_stub linux FreeBSD)"

  TEST_LOG="$darwin_log" PATH="$darwin_bin:$PATH" bash "$repo/init.sh" >/dev/null
  TEST_LOG="$linux_log" PATH="$linux_bin:$PATH" bash "$repo/init.sh" >/dev/null
  darwin_actual="$(cat "$darwin_log")"
  linux_actual="$(cat "$linux_log")"
  darwin_expected="$(expected_common_order)"$'\n''.config/karabiner'

  assert_equal "$darwin_expected" "$darwin_actual" \
    "Darwin runs Karabiner after .config"
  assert_equal "$(expected_common_order)" "$linux_actual" \
    "non-Darwin platforms exclude Karabiner"
}

test_exact_order_and_ignores_extra
test_failure_stops_later_modules
test_list_is_read_only
test_platform_karabiner_boundary

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
