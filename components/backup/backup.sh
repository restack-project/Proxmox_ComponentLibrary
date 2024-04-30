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
    exit
fi

if [[ -z $PBS_STORAGE ]]; then
    >&2 echo "Please specify the PBS storage name."
    exit
fi

if [[ -z $SSH_PRIVATE_KEY ]]; then
    >&2 echo "Please provide the SSH private key file name.${NC}"
    exit
fi

if [[ -z $PROXMOX_HOST ]]; then
    >&2 echo "Please specify the Proxmox host IP address or hostname."
    exit
fi

ssh -i "$SSH_PRIVATE_KEY" "$USER"@"$PROXMOX_HOST" "vzdump $VM_CT_ID --storage=\"$PBS_STORAGE\""
