# Chocolatey Installation
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
$chocoBinPath = "$env:ProgramData\chocolatey\bin"
[Environment]::SetEnvironmentVariable("Path", "$($env:Path);$chocoBinPath", [EnvironmentVariableTarget]::Machine)

# Install Chocolatey packages
choco install sysinternals --version 2023.7.26 --yes
# Java packages
choco install maven --version 3.6.3 --yes
choco install ant --version 1.10.7 --yes
choco install gradle --version 4.3 --yes
choco install make --version 4.3 --yes
choco install microsoft-openjdk11 --version 11.0.20 --yes

# Fakenet Installation
$fakenetUrl = 'https://github.com/mandiant/flare-fakenet-ng/releases/download/v1.4.11/fakenet1.4.11.zip'
$fakenetZipPath = Join-Path $env:TEMP 'fakenet1.4.11.zip'
$fakenetExtractPath = "$env:SystemDrive\fakenet1.4.11"
(New-Object System.Net.WebClient).DownloadFile($fakenetUrl, $fakenetZipPath)
Expand-Archive -Path $fakenetZipPath -DestinationPath $fakenetExtractPath

# Update Path with necessary paths
$additionalPaths = @(
    "$env:ProgramFiles\Microsoft\jdk-11.0.20.8-hotspot\bin", # openjdk
    "$env:SystemDrive\Python27", # python2
    "$env:SystemDrive\Python311", # python3
)
$additionalPathString = $additionalPaths -join ';'

[Environment]::SetEnvironmentVariable("Path", "$($env:Path);$additionalPathString", [EnvironmentVariableTarget]::Machine)

# Download Defender Remover
$defenderRemoverUrl = 'https://github.com/ionuttbara/windows-defender-remover/releases/download/release_def_12_5_1/DefenderRemover.exe'
$defenderRemoverPath = "$env:SystemDrive\DefenderRemover.exe"
(New-Object System.Net.WebClient).DownloadFile($defenderRemoverUrl, $defenderRemoverPath)
