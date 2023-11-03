#!/bin/bash
set -euo pipefail

. ./ssh_utils.sh

function vm_boot() {
    function print_help() {
        cat <<EOF
Boot a VM using QEMU.

Usage: vm_boot -d <drive-file> [-m <memory>] [-c <cpu-cores>] [-t <cpu-threads>] [-v] [-p <ssh-port>] [-n <on|off>] [-l <log-file>] [-o <options>]

Options:
    -d, --drive-file <file>           Path to the VM drive file
    -m, --memory <size>               Amount of memory to allocate to the VM
    -c, --cpu-cores <count>           Number of CPU cores to allocate to the VM
    -t, --cpu-threads <count>         Number of CPU threads to allocate to the VM
    -v, --enable-vnc                  Enable VNC for the VM
    -p, --ssh-port <port>             Port to forward SSH to
    -n, --net-restrict <on|off>       Enable or disable network restrictions
    -l, --log-file <file>             Path to the QEMU log file
    -o, --options <options>           Additional QEMU options
    -h, --help                        Display this help message
EOF
    }

    # Transform long options to short ones (https://stackoverflow.com/a/30026641)
    for arg in "$@"; do
        shift
        case "$arg" in
            "--drive-file")      set -- "$@" "-d" ;;
            "--memory")          set -- "$@" "-m" ;;
            "--cpu-cores")       set -- "$@" "-c" ;;
            "--cpu-threads")     set -- "$@" "-t" ;;
            "--enable-vnc")      set -- "$@" "-v" ;;
            "--ssh-port")        set -- "$@" "-p" ;;
            "--net-restrict")    set -- "$@" "-n" ;;
            "--log-file")        set -- "$@" "-l" ;;
            "--help")            set -- "$@" "-h" ;;
            "--options")         set -- "$@" "-o" ;;
            "--"* )              echo "Invalid option: $arg" >&2; exit 1 ;;
            *)                   set -- "$@" "$arg" ;;
        esac
    done

    # Default values
    local qemu_drive_file=""
    local qemu_memory="6G"
    local qemu_cpu_cores=2
    local qemu_cpu_threads=2
    local qemu_enable_vnc=false
    local ssh_port=2222
    local qemu_net_restrict=true
    local qemu_logfile="/dev/null"
    local qemu_options=()

    # Parse command-line options
    while getopts "d:m:c:t:vp:n:l:o:h" opt; do
        case $opt in
            d)
                qemu_drive_file="$OPTARG"
                ;;
            m)
                qemu_memory="$OPTARG"
                ;;
            c)
                qemu_cpu_cores="$OPTARG"
                ;;
            t)
                qemu_cpu_threads="$OPTARG"
                ;;
            v)
                qemu_enable_vnc=true
                ;;
            p)
                ssh_port="$OPTARG"
                ;;
            n)
                if [[ "${OPTARG}" == true ]]; then
                    qemu_net_restrict="on"
                elif [[ "${OPTARG}" == false ]]; then
                    qemu_net_restrict="off"
                else
                    echo "Invalid option: -$OPTARG" >&2
                    exit 1
                fi
                ;;
            l)
                qemu_logfile="$OPTARG"
                ;;
            o)
                qemu_options+=("$OPTARG")
                ;;
            h)
                print_help
                exit
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done

    # Check for required options
    if [ -z "$qemu_drive_file" ]; then
        echo "The -d option is required." >&2
        exit 1
    fi

    qemu_cmd=(
        "qemu-system-x86_64"
        "-enable-kvm"
        "-m" "${qemu_memory}"
        "-smp" "cores=${qemu_cpu_cores},threads=${qemu_cpu_threads}"
        "-drive" "file=${qemu_drive_file},format=qcow2"
        "-nographic"
        "-net" "user,restrict=${qemu_net_restrict},hostfwd=tcp::${ssh_port}-:22"
        "-net" "nic"
    )
    if [ "${qemu_enable_vnc}" == "yes" ]; then
        qemu_cmd+=("-vnc" ":0,share=ignore")
    fi
    qemu_cmd+=("${qemu_options[@]}")

    # Run the QEMU command in the background and capture the PID
    "${qemu_cmd[@]}" > "${qemu_logfile}" 2>&1 &
    local qemu_pid=$!

    # Return the captured PID
    echo "${qemu_pid}"
}

function vm_wait_for_boot() {
    function print_help() {
        cat <<EOF
Wait for a VM to boot.

Usage: vm_wait_for_boot -p <pid> [-t <timeout>] [-o <ssh_options>] <user:password@host:port>

Positional arguments:
    <user:password@host:port>         SSH connection string

Options:
    -p, --pid <pid>                   PID of the QEMU process
    -t, --timeout <seconds>           Timeout in seconds
    -h, --help                        Display this help message
EOF
    }

    # Transform long options to short ones (https://stackoverflow.com/a/30026641)
    for arg in "$@"; do
        shift
        case "$arg" in
            "--pid")      set -- "$@" "-p" ;;
            "--timeout")  set -- "$@" "-t" ;;
            "--help")     set -- "$@" "-h" ;;
            "--"* )       echo "Invalid option: $arg" >&2; exit 1 ;;
            *)            set -- "$@" "$arg" ;;
        esac
    done

    # Default values
    local pid=""
    local timeout=180
    local ssh_options=("-q" "-o ConnectTimeout=10" )

    # Parse command-line options
    OPTIND=1
    while getopts "p:t:h" opt; do
        case $opt in
            p)
                pid="$OPTARG"
                ;;
            t)
                timeout="$OPTARG"
                ;;
            h)
                print_help
                exit
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1)) # remove options from positional parameters

    local remote="$1"

    # Check for required options
    if [ -z "$remote" ]; then
        echo "Missing required argument: <user:password@host:port>" >&2
        exit 1
    elif [ -z "$pid" ]; then
        echo "The -p option is required." >&2
        exit 1
    fi

    # Define local variables
    local start_time
    local current_time
    local elapsed_time

    # Wait for the VM to become available
    start_time=$(date +%s)
    while true; do
        if ssh_execute "${ssh_options[@]}" "${remote}" "exit" >/dev/null 2>&1; then
            break
        fi

        # Check if the timeout has been reached
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if ((elapsed_time >= timeout)); then
            echo "Timed out. Killing the VM..."
            kill -9 "$pid"
            exit
        fi
    done
}

function vm_wait_for_shutdown() {
    function print_help() {
        cat <<EOF
Wait for a VM to shut down.

Usage: vm_wait_for_shutdown -p <pid> [-t <timeout>] [-i <interval>] [-h]

Options:
    -p, --pid <pid>                   PID of the QEMU process
    -t, --timeout <seconds>           Timeout in seconds
    -i, --interval <seconds>          Polling interval in seconds
    -h, --help                        Display this help message
EOF
    }

    # Transform long options to short ones (https://stackoverflow.com/a/30026641)
    for arg in "$@"; do
        shift
        case "$arg" in
            "--pid")      set -- "$@" "-p" ;;
            "--timeout")  set -- "$@" "-t" ;;
            "--interval") set -- "$@" "-i" ;;
            "--help")     set -- "$@" "-h" ;;
            "--"* )       echo "Invalid option: $arg" >&2; exit 1 ;;
            *)            set -- "$@" "$arg" ;;
        esac
    done

    # Default values
    local pid=""
    local timeout=180
    local interval=1

    # Parse command-line options
    OPTIND=1
    while getopts "p:t:i:h" opt; do
        case $opt in
            p)
                pid="$OPTARG"
                ;;
            t)
                timeout="$OPTARG"
                ;;
            i)
                interval="$OPTARG"
                ;;
            h)
                print_help
                exit
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done

    # Check for required options
    if [ -z "$pid" ]; then
        echo "The -p option is required." >&2
        exit 1
    fi

    # Define local variables
    local start_time
    local current_time
    local elapsed_time

    # Wait for the VM to shut down
    start_time=$(date +%s)
    while kill -0 "$pid" 2>/dev/null; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if ((elapsed_time >= timeout)); then
            echo "Timed out. Killing the VM..."
            kill -9 "$pid"
            exit
        fi

        sleep "$interval"
    done
}
