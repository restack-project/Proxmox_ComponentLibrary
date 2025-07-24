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
  check_output=$(execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "[ -d /etc/dns ] && echo 'Installed' || echo 'NotInstalled'")
  [[ $check_output == "NotInstalled" ]] && log_error "No Technitium Installation Found!"

  log_info "Updating Technitium"

  check_output=$(execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "dpkg -s aspnetcore-runtime-7.0 > /dev/null 2>&1; echo \$?")
  [[ $check_output -ne 0 ]] && log_error "Package aspnetcore-runtime-7.0 Not Installed!"

  execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "wget -q https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb"
  execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "dpkg -i packages-microsoft-prod.deb"
  execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "apt-get update"
  execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "apt-get install -y aspnetcore-runtime-7.0"
  execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "rm packages-microsoft-prod.deb"

  execute_command_on_machine 0 "$PROXMOX_HOST" "$USER" "$SSH_PRIVATE_KEY" "bash <(curl -fsSL https://download.technitium.com/dns/install.sh)"
}

## Run
update
exit 0
