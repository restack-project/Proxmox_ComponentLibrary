#!/bin/bash

PROVISION_VM="../components/provision-vm-cloudimg/provision-vm-cloudimg.sh"
SSH_PRIVATE_KEY="../keys/id_rsa"
SSH_PUBLIC_KEY="../keys/id_rsa.pub"

VM_ID="997"
VM_NAME="fedora-test"
VM_MEMORY="2048"
VM_CORES="2"
STORAGE="local-lvm"
NETWORK="vmbr0"
OS_TYPE="fedora"
PROXMOX_HOST="x.x.x.x"
USER="root"

echo "=========================================="
echo "Testing provision-vm-cloudimg with Fedora"
echo "=========================================="
echo "VM ID: $VM_ID"
echo "VM Name: $VM_NAME"
echo "Memory: $VM_MEMORY MB"
echo "Cores: $VM_CORES"
echo "Storage: $STORAGE"
echo "Network: $NETWORK"
echo "OS Type: $OS_TYPE"
echo "Proxmox Host: $PROXMOX_HOST"
echo "=========================================="

"$PROVISION_VM" \
    "$VM_ID" \
    "$VM_NAME" \
    "$VM_MEMORY" \
    "$VM_CORES" \
    "$STORAGE" \
    "$NETWORK" \
    "$OS_TYPE" \
    "$SSH_PUBLIC_KEY" \
    "$PROXMOX_HOST" \
    "$USER" \
    "$SSH_PRIVATE_KEY"

exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo "=========================================="
    echo "Fedora VM provisioning completed!"
    echo "VM ID: $VM_ID"
    echo "VM Name: $VM_NAME"
    echo "OS: $OS_TYPE (auto-downloaded latest image)"
    echo "Default user: fedora"
    echo "=========================================="
else
    echo "=========================================="
    echo "Fedora VM provisioning failed with exit code: $exit_code"
    echo "=========================================="
fi

exit $exit_code
