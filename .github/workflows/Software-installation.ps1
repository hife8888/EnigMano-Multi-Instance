# ===========================================
# Corporate App Deployment
# ===========================================

# Enforce TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Function for timestamped logging
function Timestamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Log($msg) { Write-Host "[DEPLOY $(Timestamp)] $msg" }

# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log "Restarting script with Administrator privileges..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Workspace for temporary downloads
$WorkRoot = "$env:TEMP\CorporateInstallers"
Log "Creating temporary workspace at $WorkRoot..."
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

# -------------------------------------------
# Deployment: Cloudflare WARP
# -------------------------------------------
$WARPURL = "https://downloads.cloudflareclient.com/v1/download/windows/ga"
$WARPInstaller = Join-Path $WorkRoot "Cloudflare_WARP_x64.exe"

Log "Starting silent installation for Cloudflare WARP..."
Invoke-WebRequest -Uri $WARPURL -OutFile $WARPInstaller -UseBasicParsing


Start-Process msiexec.exe -ArgumentList "/i `"$WARPInstaller`" /qn /norestart" -Wait


# -------------------------------------------
# Deployment: Brave Browser
# -------------------------------------------
$BraveURL = "https://laptop-updates.brave.com/download/BRV010"
$BraveInstaller = Join-Path $WorkRoot "BraveBrowserSetup.exe"

Log "Starting silent installation for Brave Browser..."
Invoke-WebRequest -Uri $BraveURL -OutFile $BraveInstaller -UseBasicParsing


Start-Process -FilePath $BraveInstaller -ArgumentList "/silent /install" -Wait


# -------------------------------------------
# Cleanup
# -------------------------------------------
Log "Cleaning up temporary workspace..."
Remove-Item -Path $WorkRoot -Recurse -Force

Log "Deployment process finalized."
