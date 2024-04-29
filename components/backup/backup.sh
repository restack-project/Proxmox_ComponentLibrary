#!/bin/bash

# Parameters
VM_CT_ID="$1"                
PBS_STORAGE="$2"             
PROXMOX_HOST="$3"
USER="$4"
SSH_PRIVATE_KEY="${5:-id_rsa}"

# Vars
messages=()          

# Functions
echo_message() {
    local message="$1"
    echo '{"message": "'"$message"'"}'
}

end_script(){
    exit $status
}

# Run
if [[ -z $VM_CT_ID ]]; then
    >&2 echo "Please provide the VM or CT ID."
    end_script 1
fi

if [[ -z $PBS_STORAGE ]]; then
    >&2 echo "Please specify the PBS storage name."
    end_script 1
fi

if [[ -z $SSH_PRIVATE_KEY ]]; then
    >&2 echo "Please provide the SSH private key file name.${NC}"
    end_script 1
fi

if [[ -z $PROXMOX_HOST ]]; then
    >&2 echo "Please specify the Proxmox host IP address or hostname."
    end_script 1
fi

ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER"@"$PROXMOX_HOST" "vzdump $VM_CT_ID --storage=\"$PBS_STORAGE\""



