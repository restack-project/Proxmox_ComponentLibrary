#!/usr/bin/env bash

# Parameters
VM_CT_ID="$1"          
PROXMOX_HOST="$2"  
USER="$3"
SSH_PRIVATE_KEY="${4:-id_rsa}"

#Functions
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
  check_output=$(execute_command_on_container "[ -d /etc/dns ] && echo 'Installed' || echo 'NotInstalled'")
  if [[ $check_output == "NotInstalled" ]]; then
    >&2 echo "No Technitium Installation Found!"
    exit 1
  fi

  echo "Updating Technitium"

  check_output=$(execute_command_on_container "dpkg -s aspnetcore-runtime-7.0 > /dev/null 2>&1; echo \$?")
  if [[ $check_output -ne 0 ]]; then
    >&2 echo "Package aspnetcore-runtime-7.0 Not Installed!"
    exit 1
  fi

  execute_command_on_container "wget -q https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb"
  execute_command_on_container "dpkg -i packages-microsoft-prod.deb &>/dev/null"
  execute_command_on_container "apt-get update &>/dev/null"
  execute_command_on_container "apt-get install -y aspnetcore-runtime-7.0 &>/dev/null"
  execute_command_on_container "rm packages-microsoft-prod.deb"

  execute_command_on_container "bash <(curl -fsSL https://download.technitium.com/dns/install.sh) &>/dev/null"

  echo "Updated Successfully"
}

## Run
update
exit 0
