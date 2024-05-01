#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"          
PROXMOX_HOST="$2"  
USER="$3"
DIST_UPGRADE="$4"
SSH_PRIVATE_KEY="${5:-id_rsa}"

execute_command_on_machine() {
  local command="$1"

  if [[ $VM_CT_ID == "0" || $VM_CT_ID -eq 0 ]]; then
    output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "bash -c '$command' 2>&1")
  else
    output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "pct exec $VM_CT_ID -- bash -c \"$command\" 2>&1")
  fi

  echo "$output"

  local exit_status=$?
  if [[ $exit_status -ne 0 ]]; then
    >&2 echo "Error executing command on machine ($exit_status): $command"
    exit 1
  fi
}


update() {
  execute_command_on_machine "apt-get update"
  if [[ $DIST_UPGRADE == true ]]; then
    execute_command_on_machine "apt-get dist-upgrade -y"
  else
    execute_command_on_machine "apt-get upgrade -y"
  fi
}

## Run
update
exit 0
