#!/usr/bin/env bash

set -euo pipefail

codex_dir="${HOME}/.codex"
workspace_ai_dir="/workspace/ai"
config_src="${workspace_ai_dir}/config.toml"
config_dst="${codex_dir}/config.toml"
skills_src="${workspace_ai_dir}/skills"
skills_dst="${codex_dir}/skills"
log_file="${HOME}/.codex/log/codex-tui.log"
start_size=0

mkdir -p "${codex_dir}" "${codex_dir}/log"

if [ -e "${config_dst}" ] && [ ! -L "${config_dst}" ]; then
	mv "${config_dst}" "${config_dst}.pre-symlink.$(date +%s)"
fi

if [ ! -e "${config_dst}" ]; then
	ln -s "${config_src}" "${config_dst}"
fi

if [ -e "${skills_dst}" ] && [ ! -L "${skills_dst}" ]; then
	mv "${skills_dst}" "${skills_dst}.pre-symlink.$(date +%s)"
fi

if [ ! -e "${skills_dst}" ]; then
	ln -s "${skills_src}" "${skills_dst}"
fi

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
