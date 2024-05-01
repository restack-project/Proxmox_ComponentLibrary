#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"
PROXMOX_HOST="$2"
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

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
  check_output=$(execute_command_on_machine "[ -d /opt/AdGuardHome ] && echo 'Installed' || echo 'NotInstalled'")
  if [[ $check_output == "NotInstalled" ]]; then
    >&2 echo  "No AdGuardHome Installation Found!"
    exit 1
  fi

  echo "Downloading AdGuardHome"
  execute_command_on_machine "wget -qL https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz"

  echo "Stopping AdguardHome"
  execute_command_on_machine "systemctl stop AdGuardHome"
  echo "Stopped AdguardHome"

  echo "Updating AdguardHome"
  execute_command_on_machine "tar -xvf AdGuardHome_linux_amd64.tar.gz"
  execute_command_on_machine "mkdir -p adguard-backup"
  execute_command_on_machine "cp -r /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/data adguard-backup/"
  execute_command_on_machine "cp AdGuardHome/AdGuardHome /opt/AdGuardHome/AdGuardHome"
  execute_command_on_machine " cp -r adguard-backup/* /opt/AdGuardHome/"
  echo "Updated AdguardHome"

  echo "Starting AdguardHome"
  execute_command_on_machine "systemctl start AdGuardHome"
  echo "Started AdguardHome"

  echo "Cleaning Up"
  execute_command_on_machine "rm -rf AdGuardHome_linux_amd64.tar.gz AdGuardHome /opt/AdGuardHome/adguard-backup"
  echo "Cleaned"
  echo "Updated Successfully"
}

# Run
update
exit 0