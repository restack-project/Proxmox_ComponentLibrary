#!/bin/bash

# Common functions for Proxmox Component Library

execute_command_on_machine() {
    local command="$1"
    local vm_ct_id="$2"
    local host="$3"
    local user="$4"
    local key="$5"

    if [[ $vm_ct_id == "0" || $vm_ct_id -eq 0 ]]; then
        output=$(ssh -i "$key" -o StrictHostKeyChecking=no "$user"@"$host" "bash -c '$command' 2>&1")
    else
        output=$(ssh -i "$key" -o StrictHostKeyChecking=no "$user"@"$host" "pct exec $vm_ct_id -- bash -c \"$command\" 2>&1")
    fi

    echo "$output"
    return $?
}

check_host_reachable() {
    local host="$1"
    local max_attempts="${2:-5}"
    local delay="${3:-5}"

    echo "Checking if host ${host} is reachable..."

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if ping -c 1 -W 1 "$host" &> /dev/null; then
            echo "Host ${host} is reachable."
            return 0 
        fi

        echo "Host ${host} is not reachable. Attempt ${attempt}/${max_attempts}."
        sleep "$delay"
    done

    echo "Max attempts reached. Host ${host} is still not reachable."
    return 1
}

validate_ssh_key() {
    local key="$1"
    if [[ ! -f "$key" ]]; then
        echo "SSH key file not found: $key"
        return 1
    fi
    return 0
}

wait_for_vm_ready() {
    local host="$1"
    local user="$2"
    local key="$3"
    local timeout="${4:-300}"
    local interval="${5:-10}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if ssh -i "$key" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$user"@"$host" "exit" &>/dev/null; then
            echo "VM is ready and accessible"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    echo "Timeout waiting for VM to become ready"
    return 1
}

log_error() {
    echo "ERROR: $1" >&2
    exit 1
}

log_info() {
    echo "INFO: $1"
}

validate_number() {
    local num="$1"
    local name="$2"
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        log_error "$name must be a number"
        return 1
    fi
    return 0
}
