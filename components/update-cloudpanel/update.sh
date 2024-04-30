#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"
PROXMOX_HOST="$2"
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

# Functions
execute_command_on_container() {
  local command="$1"

  pct_exec_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "pct exec $VM_CT_ID -- bash -c '$command' 2>&1")
  local exit_status=$?
  
  echo "$pct_exec_output"

  if [[ $exit_status -ne 0 ]]; then
    >&2 echo  "Error executing command on container ($exit_status): $command"
    exit 1
  fi
}

update() {
  echo "Updating Cloudpanel"
  execute_command_on_container "clp-update"
  echo "Updated Successfully"
}

# Run
update
end_script 0
