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
