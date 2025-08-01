#!/bin/bash

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

# Parameters
VM_CT_ID="$1"                
PBS_STORAGE="$2"             
PROXMOX_HOST="$3"
USER="$4"
SSH_PRIVATE_KEY="${5:-id_rsa}"

# Validate parameters
[[ -z $VM_CT_ID ]] && log_error "Please provide the VM or CT ID."
[[ -z $PBS_STORAGE ]] && log_error "Please specify the PBS storage name."
[[ -z $SSH_PRIVATE_KEY ]] && log_error "Please provide the SSH private key file name."
[[ -z $PROXMOX_HOST ]] && log_error "Please specify the Proxmox host IP address or hostname."

# Validate SSH key
validate_ssh_key "$SSH_PRIVATE_KEY" || exit 1

# Execute backup command

ssh_output=$(ssh -i "$SSH_PRIVATE_KEY" "$USER"@"$PROXMOX_HOST" "vzdump $VM_CT_ID --storage=\"$PBS_STORAGE\"" 2>&1)
ssh_exit_status=$?
if [[ $ssh_exit_status -ne 0 ]]; then
    >&2 echo "Failed to execute vzdump command over SSH. Error: $ssh_output"
    exit 1
else
    echo "$ssh_output"
    echo "vzdump command executed successfully."
fi

exit 0
