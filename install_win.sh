#!/bin/bash
# (1) opens VM (with internet)
# (2) creates paths of $vm_sandbox_path and $vm_log_path in the VM
# (3) copies scripts in $scripts_path to $vm_sandbox_path VM
# (4) copies ABEs dir of $abes_path to $vm_sandbox_path VM
# (5) allows running scripts
# (6) disables UAC and automatic windows updates
# (7) runs installer.ps1 script in the VM
# (8) create fakenet and procmon tasks in task scheduler
# (9) copies log files from $vm_log_path to host
# (10) deletes log files in $vm_log_path in the VM
# (11) closes VM

# Define host paths
host_log_path='logs/installer'
qemu_log="${host_log_path}/qemu_win.log"
host_scripts_path='scripts/installer'
host_abes_path='abes'

# Define VM paths
vm_sandbox_path='%USERPROFILE%\sandbox'
vm_log_path="${vm_sandbox_path}\\logs"
vm_fakenet_path='\fakenet1.4.11\fakenet.exe'
vm_fakenet_config_path="${vm_sandbox_path}\\fakenet-config.ini"

# Define file names
installer_name='installer.ps1'

# Define SSH settings
ssh_username_user='username'
ssh_password_user='password'
ssh_port=1022
scp_throughput=2000

# Define VM settings
vm_boot_timeout=180
vm_drive_file='windows.qcow2'
vm_memory='6G'
vm_cpu_cores=2
vm_cpu_threads=2
vm_enable_vnc='no' # Set to 'yes' or 'no', leave at 'no' if not debugging
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
    if [ "${vm_enable_vnc}" == "yes" ]; then
        qemu_cmd+=("-vnc" ":0,share=ignore")
    fi

    "${qemu_cmd[@]}" >"${qemu_log}" 2>&1 &
    declare -g qemu_pid=$! # store PID of QEMU process
}

# SSH function to execute commands on the remote VM
execute() {
    local cmd=$1
    sshpass -p "${ssh_password_user}" ssh -p $ssh_port -o StrictHostKeyChecking=no "${ssh_username_user}@localhost" "${cmd}"
}

# SCP function to copy files to the remote VM
put() {
    local source_path=$1
    local target_path=$2
    sshpass -p "${ssh_password_user}" scp -l $scp_throughput -r -P $ssh_port -o StrictHostKeyChecking=no $source_path $ssh_username_user@localhost:$target_path
}

# SCP function to copy files from the remote VM
get() {
    local source_path=$1
    local target_path=$2
    sshpass -p "${ssh_password_user}" scp -l $scp_throughput -r -P $ssh_port -o StrictHostKeyChecking=no $ssh_username_user@localhost:$source_path $target_path
}

# Function to wait for the VM to boot up or timeout
wait_for_vm() {
    start_time=$(date +%s)
    while true; do
        sshpass -p "${ssh_password_user}" ssh -p $ssh_port -q -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${ssh_username_user}@localhost" \
            "exit" >/dev/null 2>&1
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
execute "mkdir ${vm_sandbox_path} & mkdir ${vm_log_path}"

echo "Copying scripts in '${host_scripts_path}' to VM"
put "${host_scripts_path}/*" "${vm_sandbox_path}"

echo "Copying ABEs in '${host_abes_path}' to VM"
put "${host_abes_path}" "${vm_sandbox_path}"

echo 'Allow running scripts'
execute 'powershell -Command "Set-ExecutionPolicy Unrestricted -Force"'

echo 'Disabling UAC and Automatic Windows Update'
execute 'REG ADD "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f &
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v AUOptions /t REG_DWORD /d 1 /f'

echo "Executing ${installer_name} in VM (will take a while)"
execute "cd ${vm_sandbox_path} \
        & powershell -File \"${vm_sandbox_path}\\${installer_name}\"" \
    >"${host_log_path}/installer.log" 2>&1

echo "Creating tasks in Task Scheduler for Fakenet and Procmon"
execute "schtasks /create /tn \"fakenet\" /V1 /tr \"${vm_fakenet_path} --config-file=${vm_fakenet_config_path} --log-file=${vm_log_path}\\fakenet-vm.log\" /sc once /st 00:00 /sd 01/01/2023 /f /ru SYSTEM"
execute "schtasks /create /tn \"procmon\" /tr \"Procmon.exe /Quiet /Minimized /AcceptEula /BackingFile ${vm_log_path}\\procmon.pml\" /sc once /st 00:00 /sd 01/01/2023 /f /ru SYSTEM"
execute "schtasks /create /tn \"stop-procmon\" /tr \"Procmon.exe /Terminate\" /sc once /st 00:00 /sd 01/01/2023 /f /ru SYSTEM"

echo 'Shutting down the VM... (will also take a while)'
execute 'shutdown /s /f /t 0'
wait $qemu_pid
echo 'VM has been shut down.'

echo "Creating snapshot with name: ${vm_snapshot_name}"
qemu-img snapshot -c "${vm_snapshot_name}" "${vm_drive_file}"

echo 'Installation done'
