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

log_info "Starting AdGuard update for VM/CT $VM_CT_ID"

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