#!/usr/bin/env bash

# Load common library using universal loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try multiple paths to find the loader
LOADER_PATHS=(
    "$SCRIPT_DIR/../../lib/loader.sh"
    "$SCRIPT_DIR/../../../lib/loader.sh"
)

for loader_path in "${LOADER_PATHS[@]}"; do
    if [[ -f "$loader_path" ]]; then
        source "$loader_path"
        break
    fi
done

# Fallback: try to load common library directly if loader not found
if ! command -v log_info &> /dev/null; then
    COMMON_LIB_PATHS=(
        "$SCRIPT_DIR/../../lib/common.sh"
        "$SCRIPT_DIR/../../../lib/common.sh"
    )
    
    for lib_path in "${COMMON_LIB_PATHS[@]}"; do
        if [[ -f "$lib_path" ]]; then
            source "$lib_path"
            break
        fi
    done
fi

# Final check
if ! command -v log_info &> /dev/null; then
    echo "ERROR: Could not load common library functions" >&2
    exit 1
fi



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
