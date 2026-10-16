# =====================================================================
# windows-wsl-bootstrap.ps1 - Windows machine setup (runs before and
# alongside start-a-new-project.sh inside WSL)
#
# Prepares Windows for WSL2: checks the Windows version, warns about
# BIOS-level virtualization walls, enables the required Windows features,
# installs WSL + Ubuntu, and ends with the RESTART instruction.
#
# Why the fix trio exists: bcdedit (hypervisor launch) + WSL subsystem +
# VirtualMachinePlatform is the sequence that cleared the "WSL2 is not
# supported with your current machine configuration" wall on every affected
# student machine in a previous class run. All steps are idempotent.
# After this script: RESTART, open Ubuntu, create your UNIX user, then run
# start-a-new-project.sh inside Ubuntu.
#
# Usage (PowerShell as Administrator):
#   powershell -ExecutionPolicy Bypass -File windows-wsl-bootstrap.ps1          # full setup (interactive)
#   powershell -ExecutionPolicy Bypass -File windows-wsl-bootstrap.ps1 -Report  # diagnose only: gathers every
#                                                                               # check + writes the log, changes NOTHING
#
# Every run (Report or full) writes a verbose log NEXT TO THIS SCRIPT:
#   windows-wsl-bootstrap-installation.log  - attach it when asking for help.
# (Next to the script, because an elevated PowerShell otherwise starts in
#  C:\Windows\System32 and "the folder you ran this from" would be lost.)
# =====================================================================

param([switch]$Report)

$ErrorActionPreference = "Continue"

# --- failure notes + end summary ------------------------------------------------
# Every warning and nonzero exit code is remembered and printed at the end -
# a stuck student gets told to attach the log, which has everything.
$script:Notes = New-Object System.Collections.Generic.List[string]
$script:WarnHintShown = $false

function Write-Step($msg)  { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Info($msg)  { Write-Host "  $msg" }
function Write-Warn2($msg) {
    Write-Host "  WARNING: $msg" -ForegroundColor Yellow
    $script:Notes.Add($msg)
    if (-not $script:WarnHintShown -and -not $Report) {
        Write-Host "  (to diagnose without changing anything, re-run with:  -Report)" -ForegroundColor DarkGray
        $script:WarnHintShown = $true
    }
}
function Safe-StopTranscript { # never fatal if no transcript is running
    try { Stop-Transcript | Out-Null } catch { }
}
function Write-Die($msg)   { Write-Host "  FAILED: $msg" -ForegroundColor Red; $script:Notes.Add("FAILED: $msg"); Safe-StopTranscript; exit 1 }

# --- self-elevate to Administrator -----------------------------------------
# The -Report switch and the script's folder are carried through elevation:
# without them the elevated session would drop the flag and log location.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script needs Administrator rights - relaunching elevated..." -ForegroundColor Yellow
    # NOTE: -Report is carried into the elevated session. Do NOT pass
    # -WorkingDirectory here: Windows PowerShell 5.1 does not support it (only
    # pwsh 7 does) and it would fail param() binding. The log anchors to
    # $PSScriptRoot, so the elevated session's location is irrelevant.
    $argList = @("-ExecutionPolicy","Bypass","-NoExit","-File", $PSCommandPath)
    if ($Report) { $argList += "-Report" }
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList
    exit
}

# --- verbose installation log (every run that reaches a real check) ----------
# Transcript captures everything the script prints, automatically. Overwritten
# on every run, like the bash script's installation log.
$script:LogFile = Join-Path $PSScriptRoot "windows-wsl-bootstrap-installation.log"
Start-Transcript -Path $script:LogFile -Append:$false | Out-Null
Write-Host "=== windows-wsl-bootstrap installation log ==="
Write-Host ("started: " + (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") + "Z")
Write-Host ("user: $env:USERNAME   machine: $env:COMPUTERNAME   script folder: $PSScriptRoot")
Write-Host ("mode: " + $(if ($Report) { "REPORT (no changes will be made)" } else { "full setup (changes Windows features)" }))

function Show-FeatureState($name) { # read-only feature state: query, never change
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction Stop
        Write-Info ("feature $name : $($f.State)")
    } catch {
        Write-Warn2 "could not query state of feature $name ($($_.Exception.Message))"
    }
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

# --- feature status + the verified fix trio ----------------------------------
# Full setup: read the current states (logged), then apply the trio (idempotent,
# /norestart). Report mode: states only, nothing is changed or installed.
Write-Step "Windows features (state + fix trio)"
Show-FeatureState "Microsoft-Windows-Subsystem-Linux"
Show-FeatureState "VirtualMachinePlatform"
if (-not $Report) {
    bcdedit /set hypervisorlaunchtype auto
    if ($LASTEXITCODE -eq 0) { Write-Info "OK: hypervisor launch type set to auto" } else { Write-Warn2 "bcdedit returned $LASTEXITCODE (may already be set)" }

    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    if ($LASTEXITCODE -eq 0) { Write-Info "OK: Microsoft-Windows-Subsystem-Linux enabled/present" } else { Write-Warn2 "DISM WSL feature returned $LASTEXITCODE" }

    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    if ($LASTEXITCODE -eq 0) { Write-Info "OK: VirtualMachinePlatform enabled/present" } else { Write-Warn2 "DISM VMPlatform feature returned $LASTEXITCODE" }
} else {
    Write-Info "REPORT mode: skipping bcdedit + DISM (no changes made)"
}

# --- install WSL + Ubuntu ------------------------------------------------------
if (-not $Report) {
    Write-Step "Installing WSL and Ubuntu"
    wsl.exe --install -d Ubuntu
    if ($LASTEXITCODE -ne 0) {
        Write-Info "wsl --install returned $LASTEXITCODE - WSL/Ubuntu may already be installed; continuing."
    }
    wsl.exe --update
    Write-Info ("wsl --update returned: " + $LASTEXITCODE)

    wsl.exe --set-default-version 2
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "set-default-version 2 returned $LASTEXITCODE (older WSL: harmless)" }
} else {
    Write-Step "WSL status (report only)"
}

# --- sanity check ---------------------------------------------------------------
# NOTE: 'wsl --status' is read-only, so it runs in BOTH modes; it prints UTF-16,
# so its output is deliberately NOT echoed (echoing garbles the text) - only
# its exit code is used.
$wslok = $true
wsl.exe --status | Out-Null
if ($LASTEXITCODE -ne 0) {
    $wslok = $false
    Write-Warn2 "'wsl --status' failed ($LASTEXITCODE). If output says 'not supported': the feature trio"
    Write-Info "plus a RESTART usually clears it. Still failing after restart => BIOS virtualization (see preflight text)."
} else {
    Write-Info "WSL status OK"
}

# --- summary ---------------------------------------------------------------------
Write-Step "Summary"
if ($script:Notes.Count -gt 0) {
    Write-Host ("  WARNING: " + $script:Notes.Count + " warning(s) in this run (full details above and in the log):") -ForegroundColor Yellow
    foreach ($n in $script:Notes) { Write-Info "- $n" }
} else {
    Write-Info ("OK: no warnings - " + $(if ($Report) { "all checks passed; run without -Report to apply setup" } else { "setup was clean" }))
}
Write-Host ("  Log file: $script:LogFile - attach it when asking for help.")

# --- restart (full setup only, required) ------------------------------------------
if ($Report) {
    Safe-StopTranscript
    Write-Host "`nREPORT complete - nothing was changed. To apply setup, re-run without -Report." -ForegroundColor Green
    exit 0
}

Write-Step "RESTART REQUIRED"
Write-Host ""
Write-Host "  The features take effect only after a full restart." -ForegroundColor Green
Write-Host "  After restarting:" -ForegroundColor Green
Write-Host "    1. Open 'Ubuntu' from the Start menu (it will ask for a UNIX username + password"
Write-Host "       - remember that password; sudo needs it inside class scripts)"
Write-Host "    2. Put start-a-new-project.sh into your Linux home folder and run it:"
Write-Host "         cd ~"
Write-Host "         bash start-a-new-project.sh"
Write-Host ""
$ans = Read-Host "Restart this computer NOW? (y/n)"
if ($ans -eq "y") {
    Write-Info "Restarting..."
    Safe-StopTranscript
    Restart-Computer -Force
} else {
    Write-Info "Save your work and restart manually before continuing to the Ubuntu step."
    Safe-StopTranscript
}