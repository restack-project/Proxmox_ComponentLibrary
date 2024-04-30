#!/bin/bash

# Parameters
VM_CT_ID="$1"                
PBS_STORAGE="$2"             
PROXMOX_HOST="$3"
USER="$4"
SSH_PRIVATE_KEY="${5:-id_rsa}"

# Run
if [[ -z $VM_CT_ID ]]; then
    >&2 echo "Please provide the VM or CT ID."
    exit 1
fi

if [[ -z $PBS_STORAGE ]]; then
    >&2 echo "Please specify the PBS storage name."
    exit 1
fi

if [[ -z $SSH_PRIVATE_KEY ]]; then
    >&2 echo "Please provide the SSH private key file name.${NC}"
    exit 1
fi

if [[ -z $PROXMOX_HOST ]]; then
    >&2 echo "Please specify the Proxmox host IP address or hostname."
    exit 1
fi

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
