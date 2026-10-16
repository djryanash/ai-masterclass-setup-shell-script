# =====================================================================
# AI Website-Building Class — Windows bootstrap: installs WSL, fixes the
# virtualization walls students hit, ends with the RESTART instruction.
#
# Run on Windows (PowerShell as Administrator):
#   powershell -ExecutionPolicy Bypass -File windows-wsl-bootstrap.ps1
#
# The fix trio below is the sequence that unblocked every student machine
# in the 13 Oct 2026 class ("WSL2 is not supported with your current
# machine configuration"). All steps are idempotent.
# After this script: RESTART, open Ubuntu, create your UNIX user, then run
# class-setup.sh inside Ubuntu.
# =====================================================================

$ErrorActionPreference = "Continue"

function Write-Step($msg)  { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Info($msg)  { Write-Host "  $msg" }
function Write-Warn2($msg) { Write-Host "  WARNING: $msg" -ForegroundColor Yellow }
function Write-Die($msg)   { Write-Host "  FAILED: $msg" -ForegroundColor Red; exit 1 }

# --- self-elevate to Administrator ------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script needs Administrator rights - relaunching elevated..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @("-ExecutionPolicy","Bypass","-NoExit","-File", $PSCommandPath)
    exit
}

# --- Windows version gate ----------------------------------------------------
Write-Step "Checking Windows version"
$build = [System.Environment]::OSVersion.Version.Build
Write-Info ("Windows build: " + $build)
if ($build -lt 19041) {
    Write-Die "WSL2 needs Windows 10 build 19041 (2004) or newer, or Windows 11. Update Windows first."
}
Write-Info "OK: new enough for WSL2"

# --- virtualization preflight ------------------------------------------------
Write-Step "Virtualization preflight"
$cs  = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
if (-not $cs.HypervisorPresent -and ($null -ne $cpu.VirtualizationFirmwareEnabled) -and (-not $cpu.VirtualizationFirmwareEnabled)) {
    Write-Warn2 "BIOS virtualization looks DISABLED. If fixes below do not hold, reboot into BIOS/UEFI:"
    Write-Info "  - Enter BIOS at boot: F2 / Del / F12 (vendor dependent)"
    Write-Info "  - ASUS Vivobook: hold F2 while pressing power; press F7 (Advanced) -> CPU Configuration"
    Write-Info "  - Enable 'Intel Virtualization Technology' (VT-x) or 'SVM Mode' (AMD), then F10 to save"
    Write-Info "Then re-run this script."
} else {
    Write-Info "OK: hypervisor present or firmware virtualization enabled"
}

# --- the verified fix trio (idempotent, /norestart) ---------------------------
Write-Step "Enabling Windows features (bcdedit + WSL + VirtualMachinePlatform)"
bcdedit /set hypervisorlaunchtype auto
if ($LASTEXITCODE -eq 0) { Write-Info "OK: hypervisor launch type set to auto" } else { Write-Warn2 "bcdedit returned $LASTEXITCODE (may already be set)" }

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
if ($LASTEXITCODE -eq 0) { Write-Info "OK: Microsoft-Windows-Subsystem-Linux enabled/present" } else { Write-Warn2 "DISM WSL feature returned $LASTEXITCODE" }

dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
if ($LASTEXITCODE -eq 0) { Write-Info "OK: VirtualMachinePlatform enabled/present" } else { Write-Warn2 "DISM VMPlatform feature returned $LASTEXITCODE" }

# --- install WSL + Ubuntu ------------------------------------------------------
Write-Step "Installing WSL and Ubuntu"
wsl.exe --install -d Ubuntu
if ($LASTEXITCODE -ne 0) {
    Write-Info "wsl --install returned $LASTEXITCODE - WSL/Ubuntu may already be installed; continuing."
}
wsl.exe --update
Write-Info ("wsl --update returned: " + $LASTEXITCODE)

wsl.exe --set-default-version 2
if ($LASTEXITCODE -ne 0) { Write-Warn2 "set-default-version 2 returned $LASTEXITCODE (older WSL: harmless)" }

# --- sanity check ---------------------------------------------------------------
Write-Step "Sanity check"
wsl.exe --status
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "'wsl --status' failed ($LASTEXITCODE). If output says 'not supported': the trio above"
    Write-Info "plus a RESTART usually clears it. Still failing after restart => BIOS virtualization (see preflight text)."
} else {
    Write-Info "WSL status OK"
}

# --- RESTART (required) ----------------------------------------------------------
Write-Step "RESTART REQUIRED"
Write-Host ""
Write-Host "  The features take effect only after a full restart." -ForegroundColor Green
Write-Host "  After restarting:" -ForegroundColor Green
Write-Host "    1. Open 'Ubuntu' from the Start menu (it will ask for a UNIX username + password"
Write-Host "       - remember that password; sudo needs it inside class scripts)"
Write-Host "    2. Put class-setup.sh into your Linux home folder and run it:"
Write-Host "         cd ~"
Write-Host "         bash class-setup.sh"
Write-Host ""
$ans = Read-Host "Restart this computer NOW? (y/n)"
if ($ans -eq "y") {
    Write-Info "Restarting..."
    Restart-Computer -Force
} else {
    Write-Info "Save your work and restart manually before continuing to the Ubuntu step."
}