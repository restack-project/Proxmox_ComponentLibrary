#!/bin/bash

# Get the real path of this script to properly locate the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

VM_ID="$1"
VM_NAME="$2"
MEMORY="$3"
CORES="$4"
STORAGE="$5"
NETWORK="$6"
OS_TYPE="$7"
SSH_PUBLIC_KEY="$8"
PROXMOX_HOST="$9"
USER="${10}"
SSH_KEY="${11}"

[[ -z $VM_ID ]] && log_error "Please provide the VM ID."
[[ -z $VM_NAME ]] && log_error "Please provide the VM name."
[[ -z $MEMORY ]] && log_error "Please provide the memory size."
[[ -z $CORES ]] && log_error "Please provide the number of cores."
[[ -z $STORAGE ]] && log_error "Please provide the storage name."
[[ -z $NETWORK ]] && log_error "Please provide the network bridge."
[[ -z $OS_TYPE ]] && log_error "Please provide the OS type (debian/fedora/custom:path)."
[[ -z $SSH_PUBLIC_KEY ]] && log_error "Please provide the SSH public key."
[[ -z $PROXMOX_HOST ]] && log_error "Please provide the Proxmox host."
[[ -z $USER ]] && log_error "Please provide the user."
[[ -z $SSH_KEY ]] && log_error "Please provide the SSH key."

validate_ssh_key "$SSH_KEY"
validate_number "$VM_ID" "VM ID"
validate_number "$MEMORY" "Memory"
validate_number "$CORES" "Cores"

download_os_image() {
    local os_type="$1"
    
    case "$os_type" in
        "debian")
            log_info "Downloading latest Debian bookworm cloud image"
            local base_url="https://cloud.debian.org/images/cloud/bookworm/latest"
            
            local latest_dir=$(execute_command_on_machine "curl -s $base_url/ | grep -oP 'debian-[0-9]+-cloud-amd64' | sort -V | tail -1" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY")
            
            if [[ -z "$latest_dir" ]]; then
                log_error "Could not determine latest Debian image directory"
            fi
            
            local image_name="$latest_dir.qcow2"
            local download_url="$base_url/$latest_dir/$image_name"
            local local_path="/var/lib/vz/template/iso/$image_name"
            
            execute_command_on_machine "test -f '$local_path' || wget -O '$local_path' '$download_url'" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
            
            echo "$local_path"
            ;;
        "fedora")
            log_info "Downloading latest Fedora cloud image"
            local base_url="https://download.fedoraproject.org/pub/fedora/linux/releases"
            
            local latest_version=$(execute_command_on_machine "curl -s $base_url/ | grep -oP '[0-9]+/' | grep -oP '[0-9]+' | sort -n | tail -1" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY")
            
            if [[ -z "$latest_version" ]]; then
                log_error "Could not determine latest Fedora version"
            fi
            
            local cloud_url="$base_url/$latest_version/Cloud/x86_64/images"
            local image_name=$(execute_command_on_machine "curl -s $cloud_url/ | grep -oP 'Fedora-Cloud-Base-[0-9.]+-[0-9.]+\.x86_64\.qcow2' | sort -V | tail -1" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY")
            
            if [[ -z "$image_name" ]]; then
                log_error "Could not determine latest Fedora cloud image name"
            fi
            
            local download_url="$cloud_url/$image_name"
            local local_path="/var/lib/vz/template/iso/$image_name"
            
            execute_command_on_machine "test -f '$local_path' || wget -O '$local_path' '$download_url'" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
            
            echo "$local_path"
            ;;
        custom:*)
            local custom_path="${os_type#custom:}"
            log_info "Using custom image path: $custom_path"
            echo "$custom_path"
            ;;
        *)
            log_error "Unsupported OS type: $os_type. Use 'debian', 'fedora', or 'custom:/path/to/image'"
            ;;
    esac
}

provision_vm() {
    local vm_id="$1"
    local vm_name="$2"
    local memory="$3"
    local cores="$4"
    local storage="$5"
    local network="$6" 
    local os_type="$7"
    local ssh_key_content="$8"
    
    local image_path=$(download_os_image "$os_type")
    log_info "Using image: $image_path"
    
    log_info "Creating VM $vm_id with name $vm_name"
    
    execute_command_on_machine "qm create $vm_id --name '$vm_name' --memory $memory --cores $cores --net0 virtio,bridge=$network --scsihw virtio-scsi-pci" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    execute_command_on_machine "qm importdisk $vm_id '$image_path' $storage" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    execute_command_on_machine "qm set $vm_id --scsi0 $storage:vm-$vm_id-disk-0" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    execute_command_on_machine "qm set $vm_id --boot c --bootdisk scsi0" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    execute_command_on_machine "qm set $vm_id --ide2 $storage:cloudinit" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    if [[ -f "$ssh_key_content" ]]; then
        local ssh_content=$(cat "$ssh_key_content")
        execute_command_on_machine "qm set $vm_id --sshkeys '$ssh_content'" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    fi
    
    case "$os_type" in
        "debian")
            execute_command_on_machine "qm set $vm_id --ciuser debian" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
            ;;
        "fedora")
            execute_command_on_machine "qm set $vm_id --ciuser fedora" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
            ;;
        custom:*)
            execute_command_on_machine "qm set $vm_id --ciuser admin" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
            ;;
    esac
    
    execute_command_on_machine "qm set $vm_id --ipconfig0 ip=dhcp" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    execute_command_on_machine "qm set $vm_id --serial0 socket --vga serial0" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    execute_command_on_machine "qm start $vm_id" "0" "$PROXMOX_HOST" "$USER" "$SSH_KEY"
    
    log_info "VM $vm_id ($os_type) created and started successfully"
}

provision_vm "$VM_ID" "$VM_NAME" "$MEMORY" "$CORES" "$STORAGE" "$NETWORK" "$OS_TYPE" "$SSH_PUBLIC_KEY"
