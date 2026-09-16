# app-infra — terraform provisions the box, ansible configures it.
#
#   make up        one command, nothing to nothing: apply, then deploy
#   make help      everything else
#
# Variables can be overridden per-invocation, e.g.
#   make up AUTO_APPROVE=1 VAULT_PASS_FILE=~/.vault-pass
#   make inventory SSH_KEY=~/.ssh/other.pem

SHELL := /bin/bash
TF_DIR := tf
ANS_DIR := ans
PLAYBOOK := playbooks/site.yml

# Skip terraform's interactive approval (CI, or once you trust the plan).
AUTO_APPROVE ?= 0
# A file holding the vault password; unset means prompt with --ask-vault-pass.
VAULT_PASS_FILE ?=
# SSH identity written into the generated inventory; unset keeps the current one.
SSH_USER ?= admin
SSH_KEY ?=

export AUTO_APPROVE VAULT_PASS_FILE SSH_USER SSH_KEY

ifeq ($(strip $(VAULT_PASS_FILE)),)
VAULT_ARGS := --ask-vault-pass
else
VAULT_ARGS := --vault-password-file $(VAULT_PASS_FILE)
endif

# The pipeline is ordered; never let -j interleave it.
.NOTPARALLEL:
.DEFAULT_GOAL := help

.PHONY: help up init provision plan inventory wait configure check ping deploy destroy fmt

help: ## Show this help
	@echo "app-infra"
	@echo
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Vars: AUTO_APPROVE=1  VAULT_PASS_FILE=path  SSH_USER=admin  SSH_KEY=path"

up: ## Provision (terraform) then configure (ansible), end to end
	@./scripts/deploy.sh $(ARGS)

init: ## terraform init + install galaxy collections
	@terraform -chdir=$(TF_DIR) init -input=false
	@ansible-galaxy collection install -r $(ANS_DIR)/requirements.yml

plan: ## Show what terraform would change
	@terraform -chdir=$(TF_DIR) plan

provision: ## terraform apply only
	@terraform -chdir=$(TF_DIR) init -input=false
	@terraform -chdir=$(TF_DIR) apply -input=false $(if $(filter 1,$(AUTO_APPROVE)),-auto-approve,)

inventory: ## Write ans/inventory/hosts.ini from the terraform outputs
	@./scripts/inventory.sh

wait: ## Block until the instance answers SSH
	@./scripts/wait-for-ssh.sh

configure: ## Run the full playbook against the current inventory
	@cd $(ANS_DIR) && ansible-playbook $(PLAYBOOK) $(VAULT_ARGS) $(ARGS)

deploy: configure ## Roll the app forward on an existing host (alias for configure)

check: ## Dry run: what the playbook would change, and how
	@cd $(ANS_DIR) && ansible-playbook $(PLAYBOOK) $(VAULT_ARGS) --check --diff $(ARGS)

ping: ## Confirm SSH to the host works
	@cd $(ANS_DIR) && ansible hosts -m ping

fmt: ## terraform fmt
	@terraform -chdir=$(TF_DIR) fmt

destroy: ## Tear the instance down (terraform destroy)
	@terraform -chdir=$(TF_DIR) destroy
