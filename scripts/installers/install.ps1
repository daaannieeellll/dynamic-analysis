# Disable the progress bar to avoid issues when running the script from SSH
$ProgressPreference = 'SilentlyContinue'

# Function to add a path to the system or user environment variable
function Add-PathIfNotExists ([string]$PathToAdd,[System.EnvironmentVariableTarget]$Target)
{
    $ExistingPaths = [Environment]::GetEnvironmentVariable("Path", $Target)
    if ($ExistingPaths -notlike "*$PathToAdd*")
    {
        $NewPaths = "$ExistingPaths;$PathToAdd"
        [Environment]::SetEnvironmentVariable("Path", $NewPaths, $Target)
    }
}

# Chocolatey Installation
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Chocolatey packages
Write-Output "Installing Chocolatey packages"
choco install sysinternals --yes

# Conda Installation
Write-Output "Installing Miniconda"
$MinicondaUrl = 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe'
$MinicondaPath = Join-Path $env:TEMP 'miniconda3.exe'
(New-Object System.Net.WebClient).DownloadFile($MinicondaUrl, $MinicondaPath)
$MinicondaArgs = @(
    '/S',
    '/InstallationType=AllUsers',
    "/D=$env:SystemDrive\miniconda3"
)
Start-Process -Wait -FilePath $MinicondaPath -ArgumentList $MinicondaArgs

# Fakenet Installation
Write-Output "Installing Fakenet"
$FakenetUrl = 'https://github.com/mandiant/flare-fakenet-ng/releases/download/v1.4.11/fakenet1.4.11.zip'
$FakenetZipPath = Join-Path $env:TEMP 'fakenet1.4.11.zip'
$FakenetExtractPath = "$env:SystemDrive\fakenet1.4.11"
(New-Object System.Net.WebClient).DownloadFile($FakenetUrl, $FakenetZipPath)
Expand-Archive -Path $FakenetZipPath -DestinationPath $FakenetExtractPath -Force

# Update Path with necessary paths
Write-Output "Updating Path"
$PathsToAdd = @(
    "$env:SystemDrive\miniconda3\Scripts",
    "$FakenetExtractPath"
)
foreach ($PathToAdd in $PathsToAdd)
{
    Add-PathIfNotExists $PathToAdd [EnvironmentVariableTarget]::Machine
}

# Download Defender Remover
Write-Output "Downloading Defender Remover"
$DefenderRemoverUrl = 'https://github.com/ionuttbara/windows-defender-remover/releases/download/release_def_12_5_1/DefenderRemover.exe'
$DefenderRemoverPath = "$env:SystemDrive\DefenderRemover.exe"
(New-Object System.Net.WebClient).DownloadFile($DefenderRemoverUrl, $DefenderRemoverPath)

Write-Output "Installation Complete"
