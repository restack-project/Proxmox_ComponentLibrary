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
  
  echo "$pct_exec_output"
  
  local exit_status=$?
  if [[ $exit_status -ne 0 ]]; then
    >&2 echo  "Error executing command on container ($exit_status): $command"
    exit 1
  fi
}

update() {
  check_output=$(execute_command_on_container "[ -d /opt/AdGuardHome ] && echo 'Installed' || echo 'NotInstalled'")
  if [[ $check_output == "NotInstalled" ]]; then
    >&2 echo  "No AdGuardHome Installation Found!"
    exit 1
  fi

  echo "Downloading AdGuardHome"
  execute_command_on_container "wget -qL https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz"

  echo "Stopping AdguardHome"
  execute_command_on_container "systemctl stop AdGuardHome"
  echo "Stopped AdguardHome"

  echo "Updating AdguardHome"
  execute_command_on_container "tar -xvf AdGuardHome_linux_amd64.tar.gz"
  execute_command_on_container "mkdir -p adguard-backup"
  execute_command_on_container "cp -r /opt/AdGuardHome/AdGuardHome.yaml /opt/AdGuardHome/data adguard-backup/"
  execute_command_on_container "cp AdGuardHome/AdGuardHome /opt/AdGuardHome/AdGuardHome"
  execute_command_on_container " cp -r adguard-backup/* /opt/AdGuardHome/"
  echo "Updated AdguardHome"

  echo "Starting AdguardHome"
  execute_command_on_container "systemctl start AdGuardHome"
  echo "Started AdguardHome"

  echo "Cleaning Up"
  execute_command_on_container "rm -rf AdGuardHome_linux_amd64.tar.gz AdGuardHome /opt/AdGuardHome/adguard-backup"
  echo "Cleaned"
  echo "Updated Successfully"
}

# Run
update
exit 0