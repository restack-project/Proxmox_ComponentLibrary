#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"
PROXMOX_HOST="$2"
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

# Vars
messages=()

# Functions
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
  check_output=$(execute_command_on_machine "[ -d /opt/uptime-kuma ] && echo 'Installed' || echo 'NotInstalled'")
  if [[ $check_output == "NotInstalled" ]]; then
    >&2 echo "No UptimeKuma Installation Found!"
    exit 1
  fi

  LATEST=$(curl -sL https://api.github.com/repos/louislam/uptime-kuma/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
  echo "Stopping Kuma"
  execute_command_on_machine "sudo systemctl stop uptime-kuma"

  execute_command_on_machine "cd /opt/uptime-kuma && \
                                git fetch --all && \
                                git checkout $LATEST --force"
  

  echo "Updating Kuma to ${LATEST}"
  execute_command_on_machine "cd /opt/uptime-kuma && \
                                npm install --production && \
                                npm run download-dist"
  
  echo "Starting Kuma"
  execute_command_on_machine "sudo systemctl start uptime-kuma"
}

## Run
update
exit 0
