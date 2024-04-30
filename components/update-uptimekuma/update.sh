#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"
PROXMOX_HOST="$2"
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

# Vars
messages=()

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
  check_output=$(execute_command_on_container "[ -d /opt/uptime-kuma ] && echo 'Installed' || echo 'NotInstalled'")
  if [[ $check_output == "NotInstalled" ]]; then
    >&2 echo "No UptimeKuma Installation Found!"
    exit 1
  fi

  LATEST=$(curl -sL https://api.github.com/repos/louislam/uptime-kuma/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
  echo "Stopping Kuma"
  execute_command_on_container "sudo systemctl stop uptime-kuma &>/dev/null"
  echo "Stopped Kuma"

  execute_command_on_container "cd /opt/uptime-kuma && \
                                git fetch --all &>/dev/null && \
                                git checkout $LATEST --force &>/dev/null"
  
  echo "Pulled ${LATEST}"

  echo "Updating Kuma to ${LATEST}"
  execute_command_on_container "cd /opt/uptime-kuma && \
                                npm install --production &>/dev/null && \
                                npm run download-dist &>/dev/null"
  echo "Updated"
  
  echo "Starting Kuma"
  execute_command_on_container "sudo systemctl start uptime-kuma &>/dev/null"
  echo "Started"
  echo "Updated Successfully"
}

## Run
update
exit 0
