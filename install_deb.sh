#!/bin/bash
# (1) opens VM (with internet)
# (2) creates paths of $vm_sandbox_path and $vm_log_path in the VM
# (3) copies scripts in $scripts_path to $vm_sandbox_path VM
# (4) copies ABEs dir of $abes_path to $vm_sandbox_path VM
# (5) runs installer.sh script in the VM
# (6) copies log files from $vm_log_path to host
# (7) deletes log files in $vm_log_path in the VM
# (8) closes VM

# Define host paths
host_log_path='/logs/installer'
qemu_log="${host_log_path}/qemu_deb.log"
host_scripts_path='scripts/installers'
host_abes_path='abes'

# Define VM paths
vm_sandbox_path='~/sandbox'
vm_log_path="${vm_sandbox_path}/log"

# Define file names
installer_name='install.sh'

# Define SSH settings
ssh_username_user="username"
ssh_password_user="password"
ssh_username_root="root"
ssh_password_root=""
ssh_port=10022
scp_throughput=2000

# Define VM settings
vm_boot_timeout=180
vm_drive_file='ubuntu.qcow2'
vm_memory='6G'
vm_cpu_cores=2
vm_cpu_threads=2
vm_snapshot_name='tools-installed'

# Boot function to boot the VM
boot() {
    local net_restrict="$1"
    if [ "${net_restrict}" == "" ]; then
        net_restrict="on"
    fi

    qemu_cmd=(
        "qemu-system-x86_64"
        "-enable-kvm"
        "-m" "${vm_memory}"
        "-smp" "cores=${vm_cpu_cores},threads=${vm_cpu_threads}"
        "-drive" "file=${vm_drive_file},format=qcow2"
        "-nographic"
        "-net" "user,restrict=${net_restrict},hostfwd=tcp::${ssh_port}-:22"
        "-net" "nic"
    )

    "${qemu_cmd[@]}" >"${qemu_log}" 2>&1 &
    declare -g qemu_pid=$! # store PID of QEMU process
}

# SSH function to execute commands on the remote VM with root account
execute() {
    local cmd=$1
    sshpass -p "${ssh_password_root}" ssh -p $ssh_port -o StrictHostKeyChecking=no "${ssh_username_root}@localhost" "${cmd}"
}

# SCP function to copy files to the remote VM with root account
put() {
    local source_path=$1
    local target_path=$2
    sshpass -p "${ssh_password_root}" scp -l $scp_throughput -r -P $ssh_port -o StrictHostKeyChecking=no $source_path $ssh_username_root@localhost:$target_path
}

# SCP function to copy files from the remote VM with root account
get() {
    local source_path=$1
    local target_path=$2
    sshpass -p "${ssh_password_root}" scp -l $scp_throughput -r -P $ssh_port -o StrictHostKeyChecking=no $ssh_username_root@localhost:$source_path $target_path
}

# Function to wait for the VM to boot up or timeout
wait_for_vm() {
    start_time=$(date +%s)
    while true; do
        sshpass -p "${ssh_password_user}" ssh -p $ssh_port -o StrictHostKeyChecking=no -o ConnectTimeout=10 -q $ssh_username_user@localhost "exit"
        if [ $? -eq 0 ]; then
            break
        fi

        # Check if timeout has been reached
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if ((elapsed_time >= vm_boot_timeout)); then
            echo "Timed out. Killing the VM..."
            kill -9 $qemu_pid
            exit
        fi
    done
}

# Create log directory if it doesn't exist
mkdir -p "${host_log_path}"

echo 'Booting up the VM...'
boot 'off' # booting with internet access
wait_for_vm
echo 'VM has booted up.'

echo "Creating '${vm_sandbox_path}' and '${vm_log_path}' paths in VM"
execute "mkdir -p ${vm_sandbox_path} ; mkdir -p ${vm_log_path}"

echo "Copying scripts in '${host_scripts_path}' to VM"
put "${host_scripts_path}/*" "${vm_sandbox_path}"

echo "Copying ABEs in '${host_abes_path}' to VM"
put "${host_abes_path}" "${vm_sandbox_path}"

echo "Executing ${installer_name} in VM (will take a while)"
execute "bash ${vm_sandbox_path}/${installer_name}" \
    >"${host_log_path}/installer.log" 2>&1

echo "Copying log files from VM to host"
get "${vm_log_path}/*.log" "${host_log_path}"

echo "Deleting log files in '${vm_log_path}' in VM"
execute "rm ${vm_log_path}/*.log"

echo 'Shutting down the VM...'
execute 'poweroff'
wait $qemu_pid
echo 'VM has been shut down.'

echo "Creating snapshot with name: ${vm_snapshot_name}"
qemu-img snapshot -c "${vm_snapshot_name}" "${vm_drive_file}"

echo 'Installation done'
