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

messages=()

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
