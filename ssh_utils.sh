#!/bin/bash

# SSH function to execute commands on the remote VM
function ssh_execute() {
    local ssh_options=("${@:1:$(($#-2))}")  # Get all arguments except the last two
    local target="${*: -2:1}"  # Get the second last argument (the target)
    local command="${*: -1}"  # Get the last argument (the command)

    # Use a regular expression to split the argument
    if [[ "$target" =~ ^([^:]+):([^@]+)@([^:]+):(.+)$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local password="${BASH_REMATCH[2]}"
        local address="${BASH_REMATCH[3]}"
        local port="${BASH_REMATCH[4]}"
    else
        echo "Invalid argument format"
        exit
    fi

    # Construct the SSH command with the provided extra options and the command
    sshpass -p "${password}" \
        ssh -p "${port}" "${ssh_options[@]}" "${username}@${address}" \
        "${command}"
}

# SCP function to copy files to the remote VM
function ssh_put() {
    local scp_options=("${@:1:$(($#-3))}")  # Get all arguments except the last three
    local remote="${*: -3:1}"  # Get the third last argument (the remote)
    local source_path="${*: -2:1}"  # Get the second last argument (the source)
    local target_path="${*: -1}"  # Get the last argument (the target)

    if [[ "$remote" =~ ^([^:]+):([^@]+)@([^:]+):(.+)$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local password="${BASH_REMATCH[2]}"
        local address="${BASH_REMATCH[3]}"
        local port="${BASH_REMATCH[4]}"
    else
        echo "Invalid argument format"
        exit
    fi

    sshpass -p "${password}" \
        scp -r -P "${port}" "${scp_options[@]}" \
        "${source_path}" "${username}@${address}:${target_path}"
}

# SCP function to copy files from the remote VM
function ssh__get() {
    local scp_options=("${@:1:$(($#-3))}")  # Get all arguments except the last three
    local remote="${*: -3:1}"  # Get the third last argument (the remote)
    local source_path="${*: -2:1}"  # Get the second last argument (the source)
    local target_path="${*: -1}"  # Get the last argument (the target)

    if [[ "$remote" =~ ^([^:]+):([^@]+)@([^:]+):(.+)$ ]]; then
        local username="${BASH_REMATCH[1]}"
        local password="${BASH_REMATCH[2]}"
        local address="${BASH_REMATCH[3]}"
        local port="${BASH_REMATCH[4]}"
    else
        echo "Invalid argument format"
        exit
    fi

    sshpass -p "${password}" \
        scp -r -P "${port}" "${scp_options[@]}" \
        "${username}@${address}:${source_path}" "${target_path}"
}
