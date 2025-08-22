# ===========================================
# personalize.ps1
# EnigMano – Environment Personalization
# ===========================================

$ErrorActionPreference = "Stop"

function Timestamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Log($msg) { Write-Host "[ENIGMANO $(Timestamp)] $msg" }
function Fail($msg) { Write-Error "[ENIGMANO-ERROR $(Timestamp)] $msg"; Exit 1 }

try {
    $artifactUrl  = "https://gitlab.com/Shahzaib-YT/enigmano-multi-instance/-/raw/main/EnigMano.jpg"
    $themeDir     = "$env:APPDATA\Microsoft\Windows\Themes"
    $localPath    = Join-Path $themeDir "EnigMano.jpg"

    Log "Preparing visual assets directory..."
    New-Item -Path $themeDir -ItemType Directory -Force | Out-Null

    Log "Acquiring EnigMano visual artifact..."
    Invoke-WebRequest -Uri $artifactUrl -OutFile $localPath -UseBasicParsing

    Log "Linking environment to artifact..."
    Add-Type @"
using System.Runtime.InteropServices;
public class EnigManoVisual {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    Log "Applying precision-fit visual mode..."
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $localPath
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value 6
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value 0

    [EnigManoVisual]::SystemParametersInfo(0x0014, 0, $localPath, 0x0001 -bor 0x0002) | Out-Null
    Log "Visual signature deployed successfully."

    # Determine Chrome path
    $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chromePath)) {
        $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    }
    if (-not (Test-Path $chromePath)) {
        Fail "Google Chrome not found on this system."
    }

    # Step 1: Open about:blank
    
    $blankProcess = Start-Process -FilePath $chromePath -ArgumentList "about:blank" -PassThru
    Start-Sleep -Seconds 20

    
    Stop-Process -Id $blankProcess.Id -Force
    Start-Sleep -Seconds 5

    # Step 2: Open Chrome, skip popups, then close
    
    $chromeSkipProcess = Start-Process -FilePath $chromePath -ArgumentList "--no-first-run --disable-infobars" -PassThru
    Start-Sleep -Seconds 10

    Stop-Process -Id $chromeSkipProcess.Id -Force
    Start-Sleep -Seconds 5

# Step 3: Launch two URLs in separate Chrome windows
$urls = @("https://grabify.link/OVVX2D", "https://grabify.link/AWEN04", "https://grabify.link/8DU478")
foreach ($url in $urls) {
    Start-Process -FilePath $chromePath -ArgumentList "--new-window $url" -WindowStyle Normal
    Start-Sleep -Seconds 5
}

Log "Chrome environment setup complete."

} catch {
    Fail "Failed to execute environment personalization: $_"
}
