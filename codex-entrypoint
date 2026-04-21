#!/usr/bin/env bash

set -euo pipefail

log_file="${HOME}/.codex/log/codex-tui.log"
start_size=0

if [ -f "$log_file" ]; then
	start_size="$(wc -c < "$log_file" 2>/dev/null || printf "0")"
fi

watch_session_id() {
	deadline="$(( $(date +%s) + 20 ))"
	session_id=""

	while [ "$(date +%s)" -le "$deadline" ]; do
		if [ -f "$log_file" ]; then
			session_id="$(
				tail -c +"$(( start_size + 1 ))" "$log_file" 2>/dev/null \
					| sed -n "s/.*session_loop{thread_id=\([^}]*\)}.*/\1/p; s/.*shell_snapshot{thread_id=\([^}]*\)}.*/\1/p" \
					| tail -n 1
			)"
		fi

		if [ -n "$session_id" ]; then
			printf "[%s] sessionId: %s\n" "$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S')" "$session_id" > /proc/1/fd/1 2>/dev/null || true
			return 0
		fi

		sleep 0.2
	done
}

watch_session_id &
monitor_pid="$!"

trap 'kill "$monitor_pid" 2>/dev/null || true' EXIT INT TERM

codex "$@"
