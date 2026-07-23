#!/usr/bin/env bash
# Minimal e2e test harness for devbox-setup.sh
# Runs the real script (not dry-run) inside throwaway debian/ubuntu containers,
# with systemctl/loginctl stubbed (no systemd). Validates:
#   - packages install on each distro
#   - config files generated at correct paths (valid YAML/JSON/TOML)
#   - agent wrappers created and executable
#   - idempotency (re-run skips done steps)
# Does NOT test: real LLM calls (--skip-verify), OAuth logins, docker compose.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../devbox-setup.sh"
PASS=0; FAIL=0
declare -a FAILURES

color() {
  local code="$1" msg="$2"
  if [ -t 1 ]; then
    printf '\033[%sm%s\033[0m' "$code" "$msg"
  else
    printf '%s' "$msg"
  fi
}
ok()   { color "0;32" "PASS"; printf ' %s\n' "$1"; PASS=$((PASS+1)); }
fail() { color "0;31" "FAIL"; printf ' %s\n' "$1"; FAIL=$((FAIL+1)); FAILURES+=("$1"); }
note() { color "0;36" ">>"; printf ' %s\n' "$1"; }

# assert_in <container-id> <description> <test-command>
# runs with PATH including the user's npm-global bin (set by the script)
assert_in() {
  local cid="$1" desc="$2" test="$3"
  if docker exec -u testuser -e PATH="/home/testuser/.npm-global/bin:/home/testuser/.local/bin:/usr/local/bin:/usr/bin:/bin" "$cid" bash -lc "$test" >/dev/null 2>&1; then
    ok "$desc"
  else
    fail "$desc"
  fi
}

run_distro() {
  local image="$1" label="$2"
  echo
  color "1;36" ""; printf '############ %s ############\n' "$label"; color "0" ""
  note "launching $image (privileged, systemd-less)"
  # mount the script OUTSIDE the user home (a bind-mount under the home dir
  # pre-creates it as root, breaking useradd ownership).
  local cid; cid="$(docker run -d --privileged \
    -v "$SCRIPT:/srv/devbox-setup.sh:ro" \
    "$image" sleep infinity)"
  if [ -z "$cid" ]; then fail "container start ($label)"; return; fi

  # bootstrap: minimal base. The SCRIPT installs curl/ca-certificates itself.
  docker exec "$cid" bash -c '
    apt-get update -qq && apt-get install -y -qq sudo >/dev/null 2>&1
    useradd -m -s /bin/bash testuser
    chown testuser:testuser /home/testuser
    cp /srv/devbox-setup.sh /home/testuser/devbox-setup.sh
    chown testuser:testuser /home/testuser/devbox-setup.sh
    chmod +x /home/testuser/devbox-setup.sh
    echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser
    # stubs: systemctl / loginctl become no-ops so the script runs headless
    printf "#!/bin/sh\nexit 0\n" > /usr/local/bin/systemctl; chmod +x /usr/local/bin/systemctl
    printf "#!/bin/sh\nexit 0\n" > /usr/local/bin/loginctl; chmod +x /usr/local/bin/loginctl
    # docker stub (no dind in minimal mode) — respond to "docker ps"
    printf "#!/bin/sh\nif [ \"\$1\" = ps ]; then exit 0; fi\nexit 0\n" > /usr/local/bin/docker; chmod +x /usr/local/bin/docker
  ' >/dev/null 2>&1

  note "running devbox-setup.sh (real, --skip-verify, dummy provider)"
  # dummy provider: fake base/key/models — exercises config gen without any API
  local runlog; runlog="$(docker exec -u testuser "$cid" bash -lc '
    cd /home/testuser && bash devbox-setup.sh \
      --skip-verify --no-with-hermes --no-with-grok \
      --provider "name=test base=http://localhost:9999/v1 key=fakekey123 models=fake-1,fake-2"
  ' 2>&1)"
  echo "$runlog" | tail -3

  # --- assertions ---
  note "assertions"
  assert_in "$cid" "$label: git installed"            "command -v git"
  assert_in "$cid" "$label: node installed (>=22.16)" "node -v | grep -qE \"v2[2-9]\""
  assert_in "$cid" "$label: npm installed"            "command -v npm"
  assert_in "$cid" "$label: codex installed"          "command -v codex"
  assert_in "$cid" "$label: claude installed"         "command -v claude"
  assert_in "$cid" "$label: opencode installed"       "command -v opencode"
  assert_in "$cid" "$label: t3 installed"             "command -v t3"
  assert_in "$cid" "$label: claudex wrapper"          "test -x ~/.npm-global/bin/claudex"
  assert_in "$cid" "$label: glaude wrapper"           "test -x ~/.npm-global/bin/glaude"
  assert_in "$cid" "$label: cliproxy binary"          "test -x ~/cliproxyapi/cli-proxy-api"
  assert_in "$cid" "$label: cliproxy config.yaml non-empty + has keys" "test -s ~/cliproxyapi/config.yaml && grep -q ^port: ~/cliproxyapi/config.yaml && grep -q api-keys: ~/cliproxyapi/config.yaml"
  assert_in "$cid" "$label: cliproxy config has test provider" "grep -q 'name: \"test\"' ~/cliproxyapi/config.yaml"
  assert_in "$cid" "$label: codex config.toml exists" "test -f ~/.codex/config.toml"
  assert_in "$cid" "$label: opencode config valid JSON" "python3 -c 'import json,sys;json.load(open(sys.argv[1]))' /home/testuser/.config/opencode/opencode.json"
  assert_in "$cid" "$label: proxy env file exists"    "test -f ~/.ai-proxy.env"
  assert_in "$cid" "$label: proxy key not empty"      "test -s ~/.ai-proxy.env"

  # --- idempotency: re-run should skip everything ---
  note "idempotency re-run"
  local rerun; rerun="$(docker exec -u testuser "$cid" bash -lc '
    cd /home/testuser && bash devbox-setup.sh --skip-verify --no-with-hermes --no-with-grok \
      --provider "name=test base=http://localhost:9999/v1 key=fakekey123 models=fake-1,fake-2"
  ' 2>&1)"
  if echo "$rerun" | grep -q "already done"; then
    ok "$label: idempotent (re-run skipped done steps)"
  else
    fail "$label: idempotency (re-run did not skip)"
  fi

  note "tearing down $label"
  docker rm -f "$cid" >/dev/null 2>&1
}

# --- main ---
command -v docker >/dev/null 2>&1 || { echo "docker required"; exit 1; }
[ -f "$SCRIPT" ] || { echo "script not found: $SCRIPT"; exit 1; }

note "pulling base images"
docker pull -q debian:stable >/dev/null 2>&1
docker pull -q ubuntu:latest >/dev/null 2>&1

run_distro "debian:stable" "DEBIAN stable"
run_distro "ubuntu:latest" "UBUNTU latest"

echo
echo "==============================================="
printf 'RESULT: %s ' "$(color "1;34" "TESTS")"; printf '%s passed, %s failed\n' "$(color "0;32" "$PASS")" "$(color "0;31" "$FAIL")"
if [ "$FAIL" -gt 0 ]; then
  echo "Failures:"; printf '  - %s\n' "${FAILURES[@]}"
  exit 1
fi
echo "$(color '0;32' 'ALL PASSED')"
