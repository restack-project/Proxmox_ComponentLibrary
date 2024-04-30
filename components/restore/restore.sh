#!/bin/bash

# Parameters
VM_CT_ID="$1"                
PBS_STORAGE="$2"             
TARGET_STORAGE="$3"     
PROXMOX_HOST="$4"
USER="$5"
SSH_PRIVATE_KEY="${6:-id_rsa}"

# Vars
if [[ $VM_CT_ID =~ ^q ]]; then
    RESTORE_CMD="qmrestore"
    STOP_CMD="qm stop"
    START_CMD="qm start"
else
    RESTORE_CMD="pct restore"
    STOP_CMD="pct stop"
    START_CMD="pct start"
fi        


# Run
if [[ -z $VM_CT_ID ]]; then
    >&2 echo  "Please provide the VM or CT ID."
    exit 1
fi

if [[ -z $PBS_STORAGE ]]; then
    >&2 echo  "Please specify the PBS storage name."
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
    >&2 echo "Restoring $backup_entry"
fi

vmct_status=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "pct status $VM_CT_ID 2>&1")
if [[ $vmct_status != "status: stopped" ]]; then
    stopctvm_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "$STOP_CMD $VM_CT_ID 2>&1")
    exit_status=$?
    if [[ $exit_status -ne 0 ]]; then
        >&2 echo "Failed to stop the container/VM. Error: $stopctvm_output"
        exit 1
    else
        >&2 echo  "Container/VM stopped successfully."
    fi
fi

restore_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "$RESTORE_CMD $VM_CT_ID $backup_entry --storage $TARGET_STORAGE --force 2>&1")
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    >&2 echo "Failed to restore container/VM. Error: $restore_output"
    exit 1
else
    >&2 echo "Container/VM restored successfully."
fi

startctvm_output=$(ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "$START_CMD $VM_CT_ID 2>&1")
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    >&2 echo "Failed to started container/VM. Error: $startctvm_output"
    exit 1
else
    >&2 echo " Container/VM started successfully."
fi

exit 0