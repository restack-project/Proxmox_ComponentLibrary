#!/usr/bin/env bash

source "$(dirname "$0")/../../lib/common.sh"

VM_CT_ID="$1"          
PROXMOX_HOST="$2"  
USER="$3"
DIST_UPGRADE="$4"
SSH_PRIVATE_KEY="${5:-id_rsa}"

[[ -z $VM_CT_ID ]] && log_error "Please provide the VM or CT ID."
[[ -z $PROXMOX_HOST ]] && log_error "Please specify the Proxmox host."
[[ -z $USER ]] && log_error "Please specify the user."

validate_ssh_key "$SSH_PRIVATE_KEY" || exit 1

log_info "Starting Alpine update for VM/CT $VM_CT_ID"


update() {
  execute_command_on_machine "apt-get update"

  if [[ $DIST_UPGRADE == true ]]; then
   execute_command_on_machine "apk update"
  else
    execute_command_on_machine "apk upgrade"
  fi

}

## Run
update
exit 0
