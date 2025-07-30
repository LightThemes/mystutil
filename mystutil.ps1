############################################################################################################
###                                                                                                      ###
### MystUtil - System Optimization and Maintenance Tool                                                  ###
###   https://github.com/LightThemes/mystutil                                                            ###
###                                                                                                      ###
############################################################################################################
#Requires -Version 5.1

[CmdletBinding()]
param (
    [switch]$DebugMode,
    [string]$Config,
    [switch]$Run,
    [switch]$NoSingleInstance
)

# Performance optimizations
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# Memory optimization
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

# Global synchronized hashtable for thread safety
$script:sync = [Hashtable]::Synchronized(@{
        LogPath      = Join-Path $env:TEMP "MystUtil.log"
        ConfigPath   = Join-Path $env:APPDATA "MystUtil"
        SettingsFile = Join-Path $env:APPDATA "MystUtil\settings.json"
    })

# Dot-source function modules
$functionModules = @(
    "logging.ps1",
    "config.ps1",
    "utility.ps1",
    "cleanup.ps1",
    "install.ps1",
    "system.ps1",
    "driver.ps1",
    "admin.ps1",
    "custom.ps1",
    "ui.ps1"
)
foreach ($module in $functionModules) {
    $modulePath = Join-Path $PSScriptRoot "functions\$module"
    if (Test-Path $modulePath) {
        . $modulePath
    }
    else {
        Write-Host "Warning: Missing function module $modulePath" -ForegroundColor Yellow
    }
}

#===========================================================================
# Admin Elevation & Single Instance
#===========================================================================

if ($Host.Name -eq "ConsoleHost") {
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    $Host.UI.RawUI.ForegroundColor = "White"

    # Set console buffer size for better scrolling
    try {
        $bufferSize = $Host.UI.RawUI.BufferSize
        $bufferSize.Height = 3000
        $Host.UI.RawUI.BufferSize = $bufferSize

        # Set window size for better visibility
        $windowSize = $Host.UI.RawUI.WindowSize
        if ($windowSize.Width -lt 120) {
            $windowSize.Width = 120
        }
        if ($windowSize.Height -lt 30) {
            $windowSize.Height = 30
        }
        $Host.UI.RawUI.WindowSize = $windowSize
    }
    catch {
        # Ignore if we can't resize
    }

    Clear-Host
}

# Check for admin privileges and elevate if needed
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch] -and $_.Value) {
            $arguments += "-$($_.Key)"
        }
        elseif ($_.Value) {
            $arguments += "-$($_.Key)", "'$($_.Value)'"
        }
    }

    $argumentString = $arguments -join ' '
    $script = "& '$PSCommandPath' $argumentString"
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    exit
}

# Single instance enforcement
if (!$NoSingleInstance) {
    Get-Process -Name "powershell*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID -and $_.MainWindowTitle -like "*MystUtil*" } |
    ForEach-Object { $_.CloseMainWindow() }
}

$Host.UI.RawUI.WindowTitle = "MystUtil (Admin)"
Clear-Host

# Set console colors
if ($Host.Name -eq "ConsoleHost") {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
}

$script:ButtonConfig = @(
    @{ Name = "Clear Temp Files"; Description = "Comprehensive cleanup of temporary files and caches"; Action = "Clear-TempFiles"; Category = "Cleanup"; Icon = "[DEL]" },
    @{ Name = "Clear Browser Cache"; Description = "Removes cache files from all major browsers"; Action = "Clear-BrowserCache"; Category = "Cleanup"; Icon = "[WEB]" },
    @{ Name = "Empty Recycle Bin"; Description = "Permanently deletes all items in Recycle Bin"; Action = "Clear-RecycleBin"; Category = "Cleanup"; Icon = "[BIN]" },

    @{ Name = "Install 7-Zip"; Description = "Downloads and installs 7-Zip file archiver"; Action = "Install-7Zip"; Category = "Install"; Icon = "[ZIP]" },
    @{ Name = "Install VS Code"; Description = "Downloads and installs Visual Studio Code editor"; Action = "Install-VSCode"; Category = "Install"; Icon = "[IDE]" },
    @{ Name = "Install Chrome"; Description = "Downloads and installs Google Chrome browser"; Action = "Install-Chrome"; Category = "Install"; Icon = "[CHR]" },
    @{ Name = "Install WinRAR"; Description = "Downloads and installs WinRAR file archiver"; Action = "Install-WinRAR"; Category = "Install"; Icon = "[RAR]" },

    @{ Name = "System File Checker"; Description = "Runs SFC scan to check system file integrity"; Action = "Start-SFCScan"; Category = "System"; Icon = "[SFC]" },
    @{ Name = "Network Reset"; Description = "Resets network stack and TCP/IP configuration"; Action = "Reset-NetworkStack"; Category = "System"; Icon = "[NET]" },
    @{ Name = "Flush DNS Cache"; Description = "Clears DNS resolver cache"; Action = "Clear-DNSCache"; Category = "System"; Icon = "[DNS]" },

    @{ Name = "Clear VRChat Data"; Description = "Clears VRChat cache, logs, and temporary data"; Action = "Clear-VRChatData"; Category = "Games"; Icon = "[VRC]" },

    @{ Name = "Yurei"; Description = "For Yurei"; Action = "Invoke-Yurei"; Category = "Custom"; Icon = "[TEST]" },
    @{ Name = "Myst"; Description = "For Myst"; Action = "Invoke-Myst"; Category = "Custom"; Icon = "[TEST]" },
    @{ Name = "Disk Cleanup Tool"; Description = "Opens Windows built-in Disk Cleanup utility"; Action = "Start-DiskCleanup"; Category = "Advanced"; Icon = "[DSK]" },
    @{ Name = "Registry Editor"; Description = "Opens Windows Registry Editor (use with caution)"; Action = "Start-RegistryEditor"; Category = "Advanced"; Icon = "[REG]" },
    @{ Name = "Admin Command Prompt"; Description = "Opens elevated Command Prompt"; Action = "Start-AdminCMD"; Category = "Advanced"; Icon = "[CMD]" },
    @{ Name = "Admin PowerShell"; Description = "Opens elevated PowerShell console"; Action = "Start-AdminPowerShell"; Category = "Advanced"; Icon = "[PS1]" }
)

Write-Log "Starting MystUtil v2.1..." -Level "INFO"
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host " MystUtil - System Optimization and Maintenance Tool" -ForegroundColor Cyan
Write-Host " https://github.com/LightThemes/mystutil" -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host ""
Write-Host " Status: " -ForegroundColor White -NoNewline
Write-Host "Starting application..." -ForegroundColor Cyan
Write-Host " Mode:   " -ForegroundColor White -NoNewline
Write-Host "Administrator privileges active" -ForegroundColor Green
Write-Host " Time:   " -ForegroundColor White -NoNewline
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host ("-" * 70) -ForegroundColor DarkBlue
try {
    Initialize-UI
}
catch {
    Write-Log "Application failed to start: $($_.Exception.Message)" -Level "ERROR"
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host " APPLICATION STARTUP FAILED" -ForegroundColor Red
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host ""
    Write-Host " Error: " -ForegroundColor White -NoNewline
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host " Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
    exit 1
}
Write-Log "Application closed gracefully" -Level "INFO"
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host " MystUtil closed gracefully" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host ""