# ===========================================
# Chrome-extensions.ps1
# EnigMano – Extension & Profile Deployment
# ===========================================

$ErrorActionPreference = "Stop"

function Timestamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Stage($msg) { Write-Host "`n[ENIGMANO-STAGE $(Timestamp)] >>> $msg`n" -ForegroundColor Cyan }
function Success($msg) { Write-Host "[ENIGMANO-SUCCESS $(Timestamp)] :: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Error "[ENIGMANO-FAILURE $(Timestamp)] :: $msg"; Exit 1 }

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Fail "Administrator privileges required."
    }
}

try {
    Stage "Privilege Validation"
    Assert-Admin

    Stage "Browser Discovery"
    $chromePaths = @(
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    )
    $bravePaths = @(
        "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
        "${env:ProgramFiles}\BraveSoftware\Brave-Browser\Application\brave.exe"
    )
    $chromePath = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    $bravePath  = $bravePaths  | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $chromePath) { Fail "Google Chrome not detected." }
    if (-not $bravePath) { Fail "Brave Browser not detected." }

    Stage "Extension Policy Configuration"
    $updateUrl = "https://clients2.google.com/service/update2/crx"
    $extensions = @(
        "bkmmlbllpjdpgcgdohbaghfaecnddhni", # WebRTC Protect
        "hlbopkdbimgihmpcaohopplcbpanmjlb", # Video Quality Settings
        "kijgnjhogkjodpakfmhgleobifempckf", # Random YouTube Video
        "jplgfhpmjnbigmhklmmbgecoobifkmpa", # Proton VPN
        "bhnhbmjfaanopkalgkjoiemhekdnhanh", # Stop Autoplay Next
        "nlkaejimjacpillmajjnopmpbkbnocid", # YouTube Nonstop
        "epcnnfbjfcgphgdmggkamkmgojdagdnn", # uBlock Origin
        "mlomiejdfkolichcflejclcbmpeaniij", # Ghostery
        "lokpenepehfdekijkebhpnpcjjpngpnd", # YouTube Ad Auto Skipper
        "bgnkhhnnamicmpeenaelnjfhikgbkllg", # Adguard Ad Blocker
        "jaioibhbkffompljnnipmpkeafhpicpd"  # Tab Auto Refresh
    )

    $policyRoots = @(
        "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionSettings",
        "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionSettings"
    )

    foreach ($root in $policyRoots) {
        New-Item -Path $root -Force | Out-Null
        foreach ($id in $extensions) {
            $json = @{ installation_mode = "normal_installed"; update_url = $updateUrl } | ConvertTo-Json -Compress
            New-ItemProperty -Path $root -Name $id -Value $json -PropertyType String -Force | Out-Null
        }
        $defaultJson = @{ installation_mode = "allowed" } | ConvertTo-Json -Compress
        New-ItemProperty -Path $root -Name "*" -Value $defaultJson -PropertyType String -Force | Out-Null
    }

    Stage "Profile & Shortcut Deployment"
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $wsh = New-Object -ComObject WScript.Shell

    function Deploy-Profiles($browserName, $exePath, $baseProfileDir) {
        for ($i = 1; $i -le 3; $i++) {
            $profileDir = "$baseProfileDir\${browserName}Profile_$i"
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null

            $shortcutPath = Join-Path $desktopPath "$browserName Instance $i.lnk"
            $sc = $wsh.CreateShortcut($shortcutPath)
            $sc.TargetPath = $exePath
            $sc.Arguments  = "--user-data-dir=`"$profileDir`" --no-first-run --disable-features=PrivacySandboxSettings4"
            $sc.WorkingDirectory = Split-Path $exePath
            $sc.Save()
        }
    }

    Deploy-Profiles -browserName "Chrome" -exePath $chromePath -baseProfileDir "C:\EnigMano"
    Deploy-Profiles -browserName "Brave"  -exePath $bravePath  -baseProfileDir "C:\EnigMano"

    Stage "Policy Ingestion"
    Start-Process -FilePath $chromePath -ArgumentList "--user-data-dir=`"C:\EnigMano\ChromeProfile_1`" about:blank"
    Start-Process -FilePath $bravePath  -ArgumentList "--user-data-dir=`"C:\EnigMano\BraveProfile_1`" about:blank"
    Start-Sleep -Seconds 20
    Get-Process -Name chrome, brave -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.CloseMainWindow() | Out-Null; Start-Sleep -Milliseconds 400; if (-not $_.HasExited) { $_.Kill() } } catch { }
    }

    Stage "Verification"
    foreach ($root in $policyRoots) {
        $written = Get-ItemProperty -Path $root | Select-Object -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider
        foreach ($id in $extensions) {
            if (-not ($written.PSObject.Properties.Name -contains $id)) {
                Fail "Extension $id missing in $root"
            }
        }
    }

    Success "Extension deployment completed."

} catch {
    Fail "Execution halted: $_"
}
