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

VM_CT_ID="$1"                
PBS_STORAGE="$2"             
TARGET_STORAGE="$3"     
PROXMOX_HOST="$4"
USER="$5"
SSH_PRIVATE_KEY="${6:-id_rsa}"

[[ -z $VM_CT_ID ]] && log_error "Please provide the VM or CT ID."
[[ -z $PBS_STORAGE ]] && log_error "Please specify the PBS storage name."
[[ -z $TARGET_STORAGE ]] && log_error "Please specify the target storage."
[[ -z $PROXMOX_HOST ]] && log_error "Please specify the Proxmox host."
[[ -z $USER ]] && log_error "Please specify the user."

validate_ssh_key "$SSH_PRIVATE_KEY" || exit 1
if [[ $VM_CT_ID =~ ^q ]]; then
    RESTORE_CMD="qmrestore"
    STOP_CMD="qm stop"
    START_CMD="qm start"
else
    RESTORE_CMD="pct restore"
    STOP_CMD="pct stop"
    START_CMD="pct start"
fi        

log_info "Starting restore process for VM/CT $VM_CT_ID"
    exit 1
fi

if [[ -z $SSH_PRIVATE_KEY ]]; then
    >&2 echo  "Please provide the SSH private key file name."
    exit 1
fi

if [[ -z $PROXMOX_HOST ]]; then
    >&2 echo "Please specify the Proxmox host IP address or hostname."
    exit 1
fi

backup_entry=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "pvesm list \"$PBS_STORAGE\" --vmid \"$VM_CT_ID\"" | tail -n 1 | cut -d ' ' -f 1)
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    >&2 echo "No backup found ($exit_status): $command"
    exit 1
else
    echo "Restoring $backup_entry"
fi

vmct_status=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "pct status $VM_CT_ID 2>&1")
if [[ $vmct_status != "status: stopped" ]]; then
    stopctvm_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "$STOP_CMD $VM_CT_ID 2>&1")
    exit_status=$?
    if [[ $exit_status -ne 0 ]]; then
        >&2 echo "Failed to stop the container/VM. Error: $stopctvm_output"
        exit 1
    else
        echo  "Container/VM stopped successfully."
    fi
fi

restore_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "$RESTORE_CMD $VM_CT_ID $backup_entry --storage $TARGET_STORAGE --force 2>&1")
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    >&2 echo "Failed to restore container/VM. Error: $restore_output"
    exit 1
else
    echo "Container/VM restored successfully."
fi

startctvm_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "$START_CMD $VM_CT_ID 2>&1")
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    >&2 echo "Failed to start container/VM. Error: $startctvm_output"
    exit 1
else
    echo " Container/VM started successfully."
fi

exit 0