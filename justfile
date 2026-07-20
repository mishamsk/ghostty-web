set dotenv-load
set shell := ["bash", "-cu"]

state_dir := env_var("HOME") + "/.local/state/ghostty-web-demo"
pid_file := state_dir + "/server.pid"
log_file := state_dir + "/server.log"
launch_label := "com.coder.ghostty-web-demo.local"

# List available recipes.
default:
    @just --list

# Install the demo's pinned dependencies.
install:
    bun install --cwd demo --frozen-lockfile

# Start the local demo as a detached background process.
start: install
    #!/usr/bin/env bash
    set -euo pipefail

    [[ -f .env ]] || {
      echo "Missing .env; copy .env.example and configure it first." >&2
      exit 1
    }
    : "${HOST:?HOST must be set in .env}"
    : "${PORT:?PORT must be set in .env}"
    : "${GHOSTTY_ALLOWED_HOSTS:?GHOSTTY_ALLOWED_HOSTS must be set in .env}"

    mkdir -p "{{ state_dir }}"

    if [[ "$(uname -s)" == "Darwin" ]]; then
      service_target="gui/$(id -u)/{{ launch_label }}"
      if service_output="$(launchctl print "$service_target" 2>/dev/null)"; then
        pid="$(awk '/^[[:space:]]*pid =/ { print $3; exit }' <<<"$service_output")"
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
          printf '%s\n' "$pid" >"{{ pid_file }}"
          echo "ghostty-web demo is already running (PID $pid)"
          exit 0
        fi
        launchctl remove "{{ launch_label }}"
      fi

      repo_root="$PWD"
      node_path="$(command -v node)"
      launchctl submit \
        -l "{{ launch_label }}" \
        -o "{{ log_file }}" \
        -e "{{ log_file }}" \
        -- /usr/bin/env \
        "HOST=$HOST" \
        "PORT=$PORT" \
        "GHOSTTY_ALLOWED_HOSTS=$GHOSTTY_ALLOWED_HOSTS" \
        "$node_path" "$repo_root/demo/bin/demo.js"

      sleep 0.25
      service_output="$(launchctl print "$service_target")"
      pid="$(awk '/^[[:space:]]*pid =/ { print $3; exit }' <<<"$service_output")"
      if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        echo "ghostty-web demo failed to start; see {{ log_file }}" >&2
        exit 1
      fi

      printf '%s\n' "$pid" >"{{ pid_file }}"
      echo "ghostty-web demo started (PID $pid); logs: {{ log_file }}"
      exit 0
    fi

    if [[ -f "{{ pid_file }}" ]]; then
      pid="$(<"{{ pid_file }}")"
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        echo "ghostty-web demo is already running (PID $pid)"
        exit 0
      fi
      rm -f "{{ pid_file }}"
    fi

    repo_root="$PWD"
    detach=()
    if command -v setsid >/dev/null 2>&1; then
      detach=(setsid)
    fi
    nohup "${detach[@]}" env \
      HOST="$HOST" \
      PORT="$PORT" \
      GHOSTTY_ALLOWED_HOSTS="$GHOSTTY_ALLOWED_HOSTS" \
      node "$repo_root/demo/bin/demo.js" \
      </dev/null \
      >"{{ log_file }}" 2>&1 &

    pid=$!
    printf '%s\n' "$pid" >"{{ pid_file }}"
    disown "$pid" 2>/dev/null || true

    sleep 0.25
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "ghostty-web demo failed to start; see {{ log_file }}" >&2
      exit 1
    fi

    echo "ghostty-web demo started (PID $pid); logs: {{ log_file }}"

# Stop the detached demo recorded in the PID file.
stop:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "$(uname -s)" == "Darwin" ]]; then
      service_target="gui/$(id -u)/{{ launch_label }}"
      if ! launchctl print "$service_target" >/dev/null 2>&1; then
        rm -f "{{ pid_file }}"
        echo "ghostty-web demo is not running"
        exit 0
      fi

      pid=""
      if [[ -f "{{ pid_file }}" ]]; then
        pid="$(<"{{ pid_file }}")"
      fi
      launchctl remove "{{ launch_label }}"
      rm -f "{{ pid_file }}"
      echo "ghostty-web demo stopped${pid:+ (PID $pid)}"
      exit 0
    fi

    if [[ ! -f "{{ pid_file }}" ]]; then
      echo "ghostty-web demo is not running (no PID file)"
      exit 0
    fi

    pid="$(<"{{ pid_file }}")"
    if [[ ! "$pid" =~ ^[0-9]+$ ]] || ! kill -0 "$pid" 2>/dev/null; then
      rm -f "{{ pid_file }}"
      echo "Removed stale ghostty-web demo PID file"
      exit 0
    fi

    repo_root="$PWD"
    command="$(ps -p "$pid" -o command=)"
    if [[ "$command" != *"$repo_root/demo/bin/demo.js"* ]]; then
      echo "Refusing to stop PID $pid because it is not this checkout's demo process" >&2
      exit 1
    fi

    kill "$pid"
    rm -f "{{ pid_file }}"
    echo "ghostty-web demo stopped (PID $pid)"

# Restart the detached demo.
restart: stop start

# Show whether the detached demo is running.
status:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "$(uname -s)" == "Darwin" ]]; then
      service_target="gui/$(id -u)/{{ launch_label }}"
      if service_output="$(launchctl print "$service_target" 2>/dev/null)"; then
        pid="$(awk '/^[[:space:]]*pid =/ { print $3; exit }' <<<"$service_output")"
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
          printf '%s\n' "$pid" >"{{ pid_file }}"
          echo "ghostty-web demo is running (PID $pid)"
          exit 0
        fi
      fi

      echo "ghostty-web demo is not running"
      exit 1
    fi

    if [[ -f "{{ pid_file }}" ]]; then
      pid="$(<"{{ pid_file }}")"
      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        echo "ghostty-web demo is running (PID $pid)"
        exit 0
      fi
    fi

    echo "ghostty-web demo is not running"
    exit 1

# Follow the detached demo's log.
logs:
    @mkdir -p "{{ state_dir }}"
    touch "{{ log_file }}"
    tail -f "{{ log_file }}"
