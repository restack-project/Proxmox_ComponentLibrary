#!/usr/bin/env bash

# Parameters
PROXMOX_HOST="$1"
USER="$2"
SSH_PRIVATE_KEY="${3:-id_rsa}"

CONFIG_FILE="components/provision-vm/config/nodes.yaml"
YQ_REMOTE="yq"

# Helper
execute_remote_command() {
  local command="$1"
  ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$USER@$PROXMOX_HOST" "bash -c '$command'"
  local exit_status=$?
  if [[ $exit_status -ne 0 ]]; then
    >&2 echo "❌ Error executing command on host: $command"
    exit 1
  fi
}

# Run provisioning
provision_vms() {
  echo "🔧 [provision-vm] Starting VM provisioning on $PROXMOX_HOST..."

  # Upload config + SSH sleutel
  scp -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no "$CONFIG_FILE" "$USER@$PROXMOX_HOST:/tmp/nodes.yaml"

  execute_remote_command "
    set -e
    NODES_YAML=/tmp/nodes.yaml
    STORAGE_CMD=yq
    if ! command -v yq &>/dev/null; then echo 'yq is required on the remote host'; exit 1; fi

    for index in \$(\$STORAGE_CMD e '.nodes | keys | .[]' \$NODES_YAML); do
      NAME=\$(\$STORAGE_CMD e \".nodes[\$index].name\" \$NODES_YAML)
      VMID=\$(\$STORAGE_CMD e \".nodes[\$index].vmid\" \$NODES_YAML)
      TEMPLATE=\$(\$STORAGE_CMD e \".nodes[\$index].template_id\" \$NODES_YAML)
      CPU=\$(\$STORAGE_CMD e \".nodes[\$index].cpu\" \$NODES_YAML)
      RAM=\$(\$STORAGE_CMD e \".nodes[\$index].ram\" \$NODES_YAML)
      CIUSER=\$(\$STORAGE_CMD e \".nodes[\$index].ciuser\" \$NODES_YAML)
      CIPASSWORD=\$(\$STORAGE_CMD e \".nodes[\$index].cipassword\" \$NODES_YAML)
      SSHKEY=\$(\$STORAGE_CMD e \".nodes[\$index].sshkey_path\" \$NODES_YAML)
      DISK_SIZE=\$(\$STORAGE_CMD e \".nodes[\$index].disk\" \$NODES_YAML)
      STORAGE=\$(\$STORAGE_CMD e \".nodes[\$index].target_storage\" \$NODES_YAML)

      echo \"🔨 Cloning VM \$NAME (\$VMID) from template \$TEMPLATE to storage \$STORAGE...\"

      qm clone \$TEMPLATE \$VMID --name \$NAME --full true --storage \$STORAGE

      qm set \$VMID \\
        --memory \$RAM \\
        --cores \$CPU \\
        --bios ovmf \\
        --machine q35 \\
        --scsihw virtio-scsi-pci \\
        --ide2 \${STORAGE}:cloudinit \\
        --ciuser \$CIUSER \\
        --cipassword \$CIPASSWORD \\
        --sshkey \"\$(cat \$SSHKEY)\" \\
        --ipconfig0 ip=dhcp \\
        --net0 virtio,bridge=vmbr0,firewall=1 \\
        --efidisk0 \${STORAGE}:0,efitype=4m,pre-enrolled-keys=1,size=4M \\
        --tpmstate0 \${STORAGE}:0,version=v2.0,size=4M

      echo \"💽 Resizing disk for VM \$VMID to \$DISK_SIZE...\"
      qm resize \$VMID scsi0 \$DISK_SIZE

      echo \"🚀 Starting VM \$VMID...\"
      qm start \$VMID
    done

    echo '✅ All VMs provisioned successfully.'
  "
}

### EXECUTION ###
provision_vms
exit 0
