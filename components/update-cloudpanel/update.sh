#!/usr/bin/env bash

source "$(dirname "$0")/../../lib/common.sh"

VM_CT_ID="$1"
PROXMOX_HOST="$2"
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

[[ -z $VM_CT_ID ]] && log_error "Please provide the VM or CT ID."
[[ -z $PROXMOX_HOST ]] && log_error "Please specify the Proxmox host."
[[ -z $USER ]] && log_error "Please specify the user."

validate_ssh_key "$SSH_PRIVATE_KEY" || exit 1

update() {
  echo "Updating Cloudpanel"
  execute_command_on_machine "clp-update"
}

# Run
update
exit 0
