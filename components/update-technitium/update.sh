#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"          
PROXMOX_HOST="$2"  
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

#Functions
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
  check_output=$(execute_command_on_machine "[ -d /etc/dns ] && echo 'Installed' || echo 'NotInstalled'")
  if [[ $check_output == "NotInstalled" ]]; then
    >&2 echo "No Technitium Installation Found!"
    exit 1
  fi

  echo "Updating Technitium"

  check_output=$(execute_command_on_machine "dpkg -s aspnetcore-runtime-7.0 > /dev/null 2>&1; echo \$?")
  if [[ $check_output -ne 0 ]]; then
    >&2 echo "Package aspnetcore-runtime-7.0 Not Installed!"
    exit 1
  fi

  execute_command_on_machine "wget -q https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb"
  execute_command_on_machine "dpkg -i packages-microsoft-prod.deb"
  execute_command_on_machine "apt-get update"
  execute_command_on_machine "apt-get install -y aspnetcore-runtime-7.0"
  execute_command_on_machine "rm packages-microsoft-prod.deb"

  execute_command_on_machine "bash <(curl -fsSL https://download.technitium.com/dns/install.sh)"
}

## Run
update
exit 0
