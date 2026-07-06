#!/usr/bin/env bash
# Detects the stuck state where krc721d --local stays up but the child rusty-kaspa
# process has exited (no wRPC listener). systemd Restart=on-failure does not fire
# because the parent never exits.
#
# Install:
#   sudo install -m 0755 setup/krc721-watchdog.sh /usr/local/sbin/krc721-watchdog.sh
#   sudo install -m 0644 setup/systemd/krc721-watchdog.service /etc/systemd/system/
#   sudo install -m 0644 setup/systemd/krc721-watchdog.timer /etc/systemd/system/
#   sudo systemctl daemon-reload && sudo systemctl enable --now krc721-watchdog.timer

set -euo pipefail

STATE_DIR=/var/lib/krc721-watchdog
# Consecutive failed checks before restart (interval is timer period, default 2 min).
MISSES_BEFORE_RESTART="${KRC721_WATCHDOG_MISSES:-3}"

mkdir -p "$STATE_DIR"

port_listening() {
	local port="$1"
	ss -tln 2>/dev/null | awk -v "p=:$port" '$4 ~ p { found=1 } END { exit found ? 0 : 1 }'
}

check_stack() {
	local service="$1"
	local port="$2"
	local id="$3"
	local state_file="$STATE_DIR/${id}.misses"

	if ! systemctl is-active --quiet "$service"; then
		echo 0 >"$state_file"
		return 0
	fi

	if port_listening "$port"; then
		echo 0 >"$state_file"
		return 0
	fi

	local miss
	miss=$(($(cat "$state_file" 2>/dev/null || echo 0) + 1))
	echo "$miss" >"$state_file"

	if ((miss >= MISSES_BEFORE_RESTART)); then
		logger -t krc721-watchdog \
			"${service}: no TCP listener on port ${port} after ${miss} checks; restarting service"
		systemctl restart "$service"
		echo 0 >"$state_file"
	fi
}

# Ports must match krc721d --local embedded kaspad (mainnet 17110, testnet-10 17210).
check_stack krc721-mainnet 17110 mainnet
check_stack krc721-testnet-10 17210 testnet-10
