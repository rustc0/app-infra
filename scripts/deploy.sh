#!/usr/bin/env bash
# Provision, then configure: the whole path from nothing to a running app.
#
#   terraform apply -> render inventory -> wait for sshd -> ansible-playbook
#
# Every step is idempotent, so re-running this on an existing stack is a deploy
# rather than a rebuild. Invoked by 'make up'.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf_dir="$repo_root/tf"
ans_dir="$repo_root/ans"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# --- preflight ---------------------------------------------------------------
# Fail here rather than halfway through, with an instance running and no way to
# configure it.
for bin in terraform ansible ansible-playbook ansible-galaxy; do
	command -v "$bin" >/dev/null 2>&1 || { echo "error: '$bin' not on PATH" >&2; exit 1; }
done

if [[ ! -f "$ans_dir/secrets/vault.yml" ]]; then
	echo "error: $ans_dir/secrets/vault.yml is missing." >&2
	echo "       The app role needs vault_postgres_password and vault_jwt_secret." >&2
	echo "       See 'First run only' in README.md." >&2
	exit 1
fi

# Vault password: a file if you have one (CI, or a local pass-through), an
# interactive prompt otherwise.
vault_args=(--ask-vault-pass)
if [[ -n "${VAULT_PASS_FILE:-}" ]]; then
	[[ -f "$VAULT_PASS_FILE" ]] || { echo "error: VAULT_PASS_FILE '$VAULT_PASS_FILE' does not exist" >&2; exit 1; }
	vault_args=(--vault-password-file "$VAULT_PASS_FILE")
fi

apply_args=(-input=false)
[[ "${AUTO_APPROVE:-0}" == "1" ]] && apply_args+=(-auto-approve)

# --- provision ---------------------------------------------------------------
step "terraform init"
terraform -chdir="$tf_dir" init -input=false

step "terraform apply"
terraform -chdir="$tf_dir" apply "${apply_args[@]}"

step "render ansible inventory from terraform outputs"
"$repo_root/scripts/inventory.sh"

# --- configure ---------------------------------------------------------------
step "wait for sshd"
"$repo_root/scripts/wait-for-ssh.sh"

step "install galaxy collections"
ansible-galaxy collection install -r "$ans_dir/requirements.yml"

step "ansible-playbook site.yml"
cd "$ans_dir"
ansible-playbook playbooks/site.yml "${vault_args[@]}" "$@"

step "done"
echo "app: https://$(terraform -chdir="$tf_dir" output -raw public_ip)/  (self-signed cert, expect a warning)"
