#!/usr/bin/env bash
# Block until the instance answers SSH.
#
# A fresh EC2 instance accepts an 'apply' long before sshd is up, so running the
# playbook straight after Terraform fails on 'unreachable' rather than anything
# real. Poll instead of guessing at a sleep.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
attempts="${SSH_WAIT_ATTEMPTS:-30}"
delay="${SSH_WAIT_DELAY:-10}"

cd "$repo_root/ans"

for attempt in $(seq 1 "$attempts"); do
	if ansible hosts -m ping -o >/dev/null 2>&1; then
		echo "ssh: host reachable (attempt ${attempt})"
		exit 0
	fi
	echo "ssh: not up yet (attempt ${attempt}/${attempts}), retrying in ${delay}s"
	sleep "$delay"
done

echo "error: host did not answer SSH after $((attempts * delay))s" >&2
echo "       check the instance, the security group's ssh_allowed_cidr, and the key path in ans/inventory/hosts.ini" >&2
exit 1
