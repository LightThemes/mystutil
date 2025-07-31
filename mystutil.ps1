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

#===========================================================================
# Core Logging & Status Functions
#===========================================================================

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        [System.IO.File]::AppendAllText($script:sync.LogPath, "$logEntry`n")
    }
    catch {
        # Silently fail if logging fails
    }

    if ($DebugMode -and $Level -eq "DEBUG") {
        Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
        Write-Host "DEBUG: " -ForegroundColor Magenta -NoNewline
        Write-Host $Message -ForegroundColor Gray
    }
}

function Update-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"

    # Thread-safe UI update
    if ($script:sync.StatusText) {
        try {
            $script:sync.StatusText.Dispatcher.BeginInvoke([Action] {
                    $script:sync.StatusText.Text = $Message
                }) | Out-Null
        }
        catch {
            # Silently fail if UI update fails
        }
    }

    # Enhanced console output with improved colors and formatting
    $prefix = "[$timestamp]"
    $separator = " >> "

    switch ($Level) {
        "INFO" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host $Message -ForegroundColor Cyan
        }
        "SUCCESS" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host "SUCCESS: " -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "WARN" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host "WARNING: " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "ERROR" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host "ERROR: " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor White
        }
    }

    Write-Log $Message -Level $Level

    # Non-blocking UI refresh
    try {
        [System.Windows.Forms.Application]::DoEvents()
    }
    catch {
        # Silently fail if DoEvents fails
    }
}

#===========================================================================
# Admin Elevation & Single Instance
#===========================================================================

# Enhanced console color setup for better readability
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

#===========================================================================
# Configuration Management
#===========================================================================

class AppSettings {
    [int]$WindowWidth = 900
    [int]$WindowHeight = 700
    [string]$LastTab = "Main"
    [string]$Theme = "Dark"
}

function Initialize-Configuration {
    if (!(Test-Path $script:sync.ConfigPath)) {
        try {
            [System.IO.Directory]::CreateDirectory($script:sync.ConfigPath) | Out-Null
        }
        catch {
            Write-Log "Failed to create config directory" -Level "WARN"
        }
    }

    try {
        if (Test-Path $script:sync.SettingsFile) {
            $json = [System.IO.File]::ReadAllText($script:sync.SettingsFile)
            $script:sync.Settings = [AppSettings]($json | ConvertFrom-Json)
        }
        else {
            $script:sync.Settings = [AppSettings]::new()
            Save-Configuration
        }
    }
    catch {
        $script:sync.Settings = [AppSettings]::new()
        Write-Log "Failed to load settings, using defaults" -Level "WARN"
    }
}

function Save-Configuration {
    try {
        $json = $script:sync.Settings | ConvertTo-Json -Depth 2
        [System.IO.File]::WriteAllText($script:sync.SettingsFile, $json)
    }
    catch {
        Write-Log "Failed to save configuration" -Level "ERROR"
    }
}

Initialize-Configuration

#===========================================================================
# Utility Functions
#===========================================================================

function Get-FolderSize {
    [CmdletBinding()]
    param([string]$Path)

    if (![System.IO.Directory]::Exists($Path)) { return 0 }

    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    }
    catch {
        return 0
    }
}

function Remove-ItemsSafely {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$Description
    )

    if (![System.IO.Directory]::Exists($Path)) {
        Update-Status "Skipped: $Description (not found)" "WARN"
        return 0
    }

    $sizeBefore = Get-FolderSize -Path $Path

    try {
        $items = @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)

        if ($items.Count -gt 0) {
            Update-Status "Clearing: $Description ($($items.Count) items)..."
            foreach ($item in $items) {
                try {
                    # Add -Confirm:$false to bypass prompts
                    Remove-Item -Path $item.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                }
                catch {
                    # Continue with other items
                }
            }
            Update-Status "Cleared: $Description - $($items.Count) items (${sizeBefore}MB)"
        }
        else {
            Update-Status "Skipped: $Description (empty)"
        }
    }
    catch {
        Update-Status "Failed: $Description - $($_.Exception.Message)" "ERROR"
        return 0
    }

    return $sizeBefore
}

function Install-Software {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Url,
        [string]$Arguments = "",
        [string]$FileName = ""
    )

    Update-Status "Preparing to install $Name..."

    try {
        $fileName = if ($FileName) { $FileName } else { "$($Name -replace ' ', '_')-installer.exe" }
        $installerPath = Join-Path $env:TEMP $fileName

        # Check if already installed
        $programFiles = @("${env:ProgramFiles}", "${env:ProgramFiles(x86)}")
        $isInstalled = $false

        foreach ($path in $programFiles) {
            if (Test-Path $path) {
                $existing = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*$($Name.Split(' ')[0])*" }
                if ($existing) {
                    $isInstalled = $true
                    break
                }
            }
        }

        if ($isInstalled) {
            Update-Status "$Name appears to already be installed" "WARN"
            return
        }

        Update-Status "Downloading $Name from server..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $installerPath)
        $webClient.Dispose()

        Update-Status "Installing $Name silently..."
        $process = Start-Process -FilePath $installerPath -ArgumentList $Arguments -PassThru -Wait -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Update-Status "$Name installed successfully"
        }
        else {
            Update-Status "$Name installation completed with exit code: $($process.ExitCode)" "WARN"
        }

        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    }
    catch {
        Update-Status "Failed to install $Name - $($_.Exception.Message)" "ERROR"
    }
}

#===========================================================================
# Cleanup Functions
#===========================================================================

function Clear-TempFiles {
    Update-Status "Starting comprehensive temp cleanup..."

    $tempPaths = @(
        @{ Path = $env:TEMP; Name = "User Temp Files" },
        @{ Path = "C:\Windows\Temp"; Name = "Windows Temp Files" },
        @{ Path = "C:\Windows\Prefetch"; Name = "Prefetch Files" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Name = "Internet Cache" },
        @{ Path = "$env:LOCALAPPDATA\Temp"; Name = "Local App Temp" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "Web Cache" },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Recent"; Name = "Recent Items" }
    )

    $totalFreed = 0
    foreach ($tempPath in $tempPaths) {
        $totalFreed += Remove-ItemsSafely -Path $tempPath.Path -Description $tempPath.Name
    }

    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $totalFreed += Remove-ItemsSafely -Path "C:\Windows\SoftwareDistribution\Download" -Description "Windows Update Cache"
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }
    catch {
        Update-Status "Could not clean Windows Update cache" "WARN"
    }

    Update-Status "Temp cleanup complete - ${totalFreed}MB freed" "SUCCESS"
    Write-Log "Temp cleanup completed - ${totalFreed}MB total space freed" -Level "SUCCESS"
}

function Clear-VRChatData {
    Update-Status "Starting VRChat data cleanup..."

    $vrchatPaths = @(
        "$env:USERPROFILE\AppData\LocalLow\VRChat\VRChat",
        "$env:LOCALAPPDATA\VRChat",
        "$env:APPDATA\VRChat"
    )

    $foldersToClean = @(
        "Cookies", "HTTPCache-WindowsPlayer", "TextureCache-WindowsPlayer",
        "Unity", "Logs", "Cache", "CrashDumps", "Tools", "OSC"
    )

    $totalFreed = 0
    $found = $false

    foreach ($basePath in $vrchatPaths) {
        if ([System.IO.Directory]::Exists($basePath)) {
            $found = $true
            foreach ($folder in $foldersToClean) {
                $fullPath = Join-Path $basePath $folder
                $totalFreed += Remove-ItemsSafely -Path $fullPath -Description "VRChat $folder"
            }
        }
    }

    if ($found) {
        Update-Status "VRChat cleanup complete - ${totalFreed}MB freed" "SUCCESS"
        Write-Log "VRChat cleanup completed - ${totalFreed}MB total space freed" -Level "SUCCESS"
    }
    else {
        Update-Status "No VRChat installation found" "WARN"
        Write-Log "No VRChat installation found on system" -Level "WARN"
    }
}

function Clear-BrowserCache {
    Update-Status "Starting browser cache cleanup..."

    $browsers = @(
        @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; Name = "Chrome Cache" },
        @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"; Name = "Chrome Code Cache" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; Name = "Edge Cache" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"; Name = "Edge Code Cache" },
        @{ Path = "$env:APPDATA\Mozilla\Firefox\Profiles"; Name = "Firefox"; IsFirefox = $true }
    )

    $totalFreed = 0

    foreach ($browser in $browsers) {
        if ($browser.IsFirefox -and [System.IO.Directory]::Exists($browser.Path)) {
            Get-ChildItem -Path $browser.Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $cachePath = Join-Path $_.FullName "cache2"
                $totalFreed += Remove-ItemsSafely -Path $cachePath -Description "Firefox Cache ($($_.Name))"
            }
        }
        else {
            $totalFreed += Remove-ItemsSafely -Path $browser.Path -Description $browser.Name
        }
    }

    Update-Status "Browser cleanup complete - ${totalFreed}MB freed" "SUCCESS"
    Write-Log "Browser cache cleanup completed - ${totalFreed}MB total space freed" -Level "SUCCESS"
}

function Reset-NetworkStack {
    Update-Status "Resetting network configuration..."

    $commands = @(
        @{ Cmd = "netsh winsock reset"; Desc = "Winsock reset" },
        @{ Cmd = "netsh int ip reset"; Desc = "IP stack reset" },
        @{ Cmd = "ipconfig /flushdns"; Desc = "DNS cache flush" },
        @{ Cmd = "netsh int tcp reset"; Desc = "TCP stack reset" }
    )

    foreach ($command in $commands) {
        Update-Status "Executing: $($command.Desc)"
        try {
            Invoke-Expression $command.Cmd | Out-Null
            Update-Status "Completed: $($command.Desc)"
        }
        catch {
            Update-Status "Failed: $($command.Desc)" "ERROR"
        }
    }

    Update-Status "Network reset complete - restart recommended for full effect"
}

function Clear-RecycleBin {
    try {
        Update-Status "Emptying Recycle Bin..."
        Write-Log "Starting Recycle Bin cleanup..." -Level "INFO"

        # Method 1: Try PowerShell cmdlet with timeout
        $job = Start-Job -ScriptBlock {
            try {
                Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
                return "Success"
            }
            catch {
                return "Failed: $($_.Exception.Message)"
            }
        }

        # Wait for job with timeout (10 seconds max)
        $completed = Wait-Job $job -Timeout 10

        if ($completed) {
            $result = Receive-Job $job
            Remove-Job $job

            if ($result -eq "Success") {
                Update-Status "Recycle Bin emptied successfully" "INFO"
                Write-Log "Recycle Bin cleared via PowerShell cmdlet" -Level "INFO"
                return
            }
        }
        else {
            # Job timed out, kill it
            Remove-Job $job -Force
            Write-Log "PowerShell Clear-RecycleBin timed out, trying alternative method" -Level "WARN"
        }

        # Method 2: COM object fallback
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(10)

            if ($recycleBin.Items().Count -gt 0) {
                # Empty recycle bin using COM
                $recycleBin.Self.InvokeVerb("Empty")
                Start-Sleep -Seconds 2  # Give it time to process
                Update-Status "Recycle Bin emptied successfully (via COM)" "INFO"
                Write-Log "Recycle Bin cleared via COM object" -Level "INFO"
            }
            else {
                Update-Status "Recycle Bin is already empty" "INFO"
                Write-Log "Recycle Bin was already empty" -Level "INFO"
            }
        }
        catch {
            # Method 3: Command line fallback
            try {
                Write-Log "Trying command line method for Recycle Bin" -Level "INFO"
                $result = cmd /c "rd /s /q C:\`$Recycle.Bin" 2>&1
                Update-Status "Recycle Bin cleared via command line" "INFO"
                Write-Log "Recycle Bin cleared via command line" -Level "INFO"
            }
            catch {
                Update-Status "Could not empty Recycle Bin - may already be empty or in use" "WARN"
                Write-Log "All Recycle Bin clearing methods failed" -Level "WARN"
            }
        }
    }
    catch {
        Update-Status "Failed to empty Recycle Bin: $($_.Exception.Message)" "ERROR"
        Write-Log "Recycle Bin cleanup failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Start-DiskCleanup {
    try {
        Update-Status "Running automated disk cleanup..."

        # Run disk cleanup with all options enabled, no UI
        $process = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -PassThru -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Update-Status "Automated disk cleanup completed successfully"
        }
        else {
            Update-Status "Disk cleanup completed with exit code: $($process.ExitCode)" "WARN"
        }
    }
    catch {
        Update-Status "Failed to run automated disk cleanup: $($_.Exception.Message)" "ERROR"
    }
}

function Install-7Zip {
    Install-Software -Name "7-Zip" -Url "https://www.7-zip.org/a/7z2301-x64.exe" -Arguments "/S"
}

function Install-VSCode {
    Install-Software -Name "VS Code" -Url "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" -Arguments "/VERYSILENT /NORESTART" -FileName "VSCode.exe"
}

function Install-Chrome {
    Install-Software -Name "Chrome" -Url "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi" -Arguments "/quiet /norestart" -FileName "Chrome.msi"
}

function Install-WinRAR {
    Install-Software -Name "WinRAR" -Url "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-623.exe" -Arguments "/S"
}

function Start-SFCScan {
    try {
        Update-Status "Starting System File Checker scan (this may take several minutes)..." "INFO"
        Write-Log "SFC scan initiated" -Level "INFO"

        # Start SFC process in background
        $job = Start-Job -ScriptBlock {
            $process = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $env:TEMP\sfc_output.txt
            return @{
                ExitCode = $process.ExitCode
                Output   = if (Test-Path "$env:TEMP\sfc_output.txt") { Get-Content "$env:TEMP\sfc_output.txt" -Raw } else { "" }
            }
        }

        # Update status while job is running
        $elapsed = 0
        while ($job.State -eq "Running") {
            Start-Sleep -Seconds 10
            $elapsed += 10
            $minutes = [math]::Floor($elapsed / 60)
            $seconds = $elapsed % 60
            Update-Status "SFC scan in progress... (${minutes}m ${seconds}s elapsed)" "INFO"
        }

        # Get result and wait for completion
        $result = Receive-Job -Job $job -Wait
        Remove-Job -Job $job

        $exitCode = $result.ExitCode
        $totalMinutes = [math]::Floor($elapsed / 60)
        $totalSeconds = $elapsed % 60

        # Report results with completion time
        switch ($exitCode) {
            0 {
                Update-Status "SFC scan completed successfully - no issues found (${totalMinutes}m ${totalSeconds}s)" "SUCCESS"
                Write-Log "SFC scan completed successfully in ${totalMinutes}m ${totalSeconds}s - no issues found" -Level "SUCCESS"
            }
            1 {
                Update-Status "SFC scan completed - issues found and repaired (${totalMinutes}m ${totalSeconds}s)" "SUCCESS"
                Write-Log "SFC scan completed in ${totalMinutes}m ${totalSeconds}s - issues found and repaired" -Level "SUCCESS"
            }
            2 {
                Update-Status "SFC scan completed - issues found but could not repair all (${totalMinutes}m ${totalSeconds}s)" "WARN"
                Write-Log "SFC scan completed in ${totalMinutes}m ${totalSeconds}s - issues found but could not repair all" -Level "WARN"
            }
            default {
                Update-Status "SFC scan completed with exit code: $exitCode (${totalMinutes}m ${totalSeconds}s)" "WARN"
                Write-Log "SFC scan completed in ${totalMinutes}m ${totalSeconds}s with exit code: $exitCode" -Level "WARN"
            }
        }

        # Small delay to show completion message
        Start-Sleep -Seconds 2

    }
    catch {
        Update-Status "Failed to run SFC scan: $($_.Exception.Message)" "ERROR"
        Write-Log "SFC scan failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Clear-DNSCache {
    try {
        Clear-DnsClientCache
        Update-Status "DNS cache flushed successfully"
    }
    catch {
        Update-Status "Failed to flush DNS cache: $($_.Exception.Message)" "ERROR"
    }
}

function Start-RegistryEditor {
    try {
        Start-Process regedit.exe
        Update-Status "Registry Editor opened - use with caution!"
    }
    catch {
        Update-Status "Failed to open Registry Editor: $($_.Exception.Message)" "ERROR"
    }
}

function Start-AdminCMD {
    try {
        Start-Process cmd.exe -Verb RunAs
        Update-Status "Admin Command Prompt opened"
    }
    catch {
        Update-Status "Failed to open Admin Command Prompt: $($_.Exception.Message)" "ERROR"
    }
}

function Start-AdminPowerShell {
    try {
        Start-Process powershell.exe -Verb RunAs
        Update-Status "Admin PowerShell opened"
    }
    catch {
        Update-Status "Failed to open Admin PowerShell: $($_.Exception.Message)" "ERROR"
    }
}

function Invoke-YureiMaintenance {
    try {
        Update-Status "Yurei's custom maintenance is starting..." "INFO"
        Write-Log "Starting Yurei's personalized system cleanup routine." -Level "INFO"

        Update-Status "Phase 1/4: Starting quick cleanup tasks..." "INFO"
        Write-Log "Phase 1: Quick cleanup tasks..." -Level "INFO"

        Clear-TempFiles
        Clear-BrowserCache
        Clear-DNSCache
        Reset-NetworkStack
        Clear-VRChatData
        Clear-RecycleBin

        Update-Status "Phase 1 complete - proceeding to system scans..." "SUCCESS"
        Write-Log "Phase 1 completed successfully" -Level "SUCCESS"

        Update-Status "Phase 2/4: Starting comprehensive system scans..." "INFO"
        Write-Log "Phase 2: System integrity scans..." -Level "INFO"

        Start-SFCScan

        Update-Status "Phase 2 complete - proceeding to hardware analysis..." "SUCCESS"
        Write-Log "Phase 2 completed successfully" -Level "SUCCESS"

        Update-Status "Phase 3/4: Starting driver analysis..." "INFO"
        Write-Log "Phase 3: Hardware and driver analysis..." -Level "INFO"

        Start-DriverCheck

        Update-Status "Phase 3 complete - proceeding to final cleanup..." "SUCCESS"
        Write-Log "Phase 3 completed successfully" -Level "SUCCESS"

        Update-Status "Phase 4/4: Starting final system cleanup..." "INFO"
        Write-Log "Phase 4: Final system cleanup..." -Level "INFO"

        Start-DiskCleanup

        Update-Status "All phases complete! Yurei's maintenance finished successfully!" "SUCCESS"
        Write-Log "All maintenance tasks completed! Yurei's system is now optimized and ready." -Level "SUCCESS"

    }
    catch {
        Update-Status "Yurei's maintenance failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Yurei's maintenance routine encountered an error: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Invoke-MystMaintenance {
    try {
        Update-Status "Myst's custom maintenance is starting..." "INFO"
        Write-Log "Starting Myst's personalized system cleanup routine." -Level "INFO"

        Update-Status "Phase 1/4: Starting quick cleanup tasks..." "INFO"
        Write-Log "Phase 1: Quick cleanup tasks..." -Level "INFO"

        Clear-TempFiles
        Clear-BrowserCache
        Clear-DNSCache
        Reset-NetworkStack
        Clear-VRChatData
        Clear-RecycleBin

        Update-Status "Phase 1 complete - proceeding to system scans..." "SUCCESS"
        Write-Log "Phase 1 completed successfully" -Level "SUCCESS"

        Update-Status "Phase 2/4: Starting comprehensive system scans..." "INFO"
        Write-Log "Phase 2: System integrity scans..." -Level "INFO"

        Start-SFCScan

        Update-Status "Phase 2 complete - proceeding to hardware analysis..." "SUCCESS"
        Write-Log "Phase 2 completed successfully" -Level "SUCCESS"

        Update-Status "Phase 3/4: Starting driver analysis..." "INFO"
        Write-Log "Phase 3: Hardware and driver analysis..." -Level "INFO"

        Start-DriverCheck

        Update-Status "Phase 3 complete - proceeding to final cleanup..." "SUCCESS"
        Write-Log "Phase 3 completed successfully" -Level "SUCCESS"

        Update-Status "Phase 4/4: Starting final system cleanup..." "INFO"
        Write-Log "Phase 4: Final system cleanup..." -Level "INFO"

        Start-DiskCleanup

        Update-Status "All phases complete! Myst's maintenance finished successfully!" "SUCCESS"
        Write-Log "All maintenance tasks completed! Myst's system is now optimized and ready." -Level "SUCCESS"

    }
    catch {
        Update-Status "Myst's maintenance failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Myst's maintenance routine encountered an error: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ================================
# Driver Analysis Function
# ================================
function Start-DriverCheck {
    try {
        Update-Status "Starting comprehensive driver analysis..." "INFO"
        Write-Log "Scanning Device Manager for driver issues..." -Level "INFO"

        # Get all PnP devices
        $allDevices = Get-WmiObject -Class Win32_PnPEntity -ErrorAction SilentlyContinue

        if (!$allDevices) {
            Update-Status "Could not retrieve device information" "ERROR"
            return
        }

        # Initialize counters
        $unknownDevices = @()
        $problemDevices = @()
        $workingDevices = @()

        # Analyze each device
        foreach ($device in $allDevices) {
            if ($device.ConfigManagerErrorCode -eq 28) {
                # Code 28 = Device doesn't have drivers installed
                $unknownDevices += $device
            }
            elseif ($device.ConfigManagerErrorCode -ne 0) {
                # Other error codes indicate driver problems
                $problemDevices += $device
            }
            elseif ($device.Status -eq "OK") {
                $workingDevices += $device
            }
        }

        # Report comprehensive results
        Write-Log "Found $($allDevices.Count) total devices, $($unknownDevices.Count) unknown, $($problemDevices.Count) with issues" -Level "INFO"

        # Log detailed findings
        if ($unknownDevices.Count -gt 0) {
            Write-Log "Found $($unknownDevices.Count) unknown devices (no drivers)" -Level "WARN"
        }

        if ($problemDevices.Count -gt 0) {
            Write-Log "Found $($problemDevices.Count) devices with driver issues" -Level "WARN"
        }

        # Final status
        if ($unknownDevices.Count -eq 0 -and $problemDevices.Count -eq 0) {
            Update-Status "Driver analysis complete - all device drivers are working correctly!" "SUCCESS"
            Write-Log "Driver analysis completed - all drivers functioning properly" -Level "SUCCESS"
        }
        else {
            Update-Status "Driver analysis complete - found $($unknownDevices.Count + $problemDevices.Count) driver issues" "WARN"
            Write-Log "Driver analysis completed with issues found" -Level "WARN"
        }

    }
    catch {
        Update-Status "Failed to analyze drivers: $($_.Exception.Message)" "ERROR"
        Write-Log "Driver analysis failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

#===========================================================================
# Button Configuration
#===========================================================================

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

    @{ Name = "Yurei"; Description = "For Yurei"; Action = "Invoke-YureiMaintenance"; Category = "Custom"; Icon = "[TEST]" },
    @{ Name = "Myst"; Description = "For Myst"; Action = "Invoke-MystMaintenance"; Category = "Custom"; Icon = "[TEST]" },

    @{ Name = "Disk Cleanup Tool"; Description = "Opens Windows built-in Disk Cleanup utility"; Action = "Start-DiskCleanup"; Category = "Advanced"; Icon = "[DSK]" },
    @{ Name = "Registry Editor"; Description = "Opens Windows Registry Editor (use with caution)"; Action = "Start-RegistryEditor"; Category = "Advanced"; Icon = "[REG]" },
    @{ Name = "Admin Command Prompt"; Description = "Opens elevated Command Prompt"; Action = "Start-AdminCMD"; Category = "Advanced"; Icon = "[CMD]" },
    @{ Name = "Admin PowerShell"; Description = "Opens elevated PowerShell console"; Action = "Start-AdminPowerShell"; Category = "Advanced"; Icon = "[PS1]" }
)

#===========================================================================
# XAML Interface
#===========================================================================

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MystUtil" Height="700" Width="900"
        WindowStartupLocation="CenterScreen" Background="#1E1E1E" MinHeight="600" MinWidth="800"
        WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize">

    <Window.Resources>
        <Style x:Key="ModernButtonStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#1E1E1E"/>
                                <Setter Property="BorderBrush" Value="#64B5F6"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#1E1E1E"/>
                                <Setter Property="BorderBrush" Value="#64B5F6"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="TabStyle" TargetType="Border">
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1E1E1E"/>
                    <Setter Property="BorderBrush" Value="#64B5F6"/>
                    <Setter Property="BorderThickness" Value="2"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="ModernScrollViewerStyle" TargetType="ScrollViewer">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollViewer">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <ScrollContentPresenter Grid.Column="0" Content="{TemplateBinding Content}"/>
                            <ScrollBar Grid.Column="1" Name="PART_VerticalScrollBar"
                                    Value="{TemplateBinding VerticalOffset}"
                                    Maximum="{TemplateBinding ScrollableHeight}"
                                    ViewportSize="{TemplateBinding ViewportHeight}"
                                    Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}"
                                    Width="12" Background="#1E1E1E" BorderThickness="0"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6">
                            <Track Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb Background="#3F3F46" BorderThickness="0" Margin="2">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="6"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CloseButtonStyle" TargetType="Border">
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1E1E1E"/>
                    <Setter Property="BorderBrush" Value="#64B5F6"/>
                    <Setter Property="BorderThickness" Value="2"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Border BorderBrush="#3F3F46" BorderThickness="2" Background="#1E1E1E">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="70"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="40"/>
            </Grid.RowDefinitions>

            <Border Name="DragArea" Grid.Row="0" Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="0,0,0,1">
                <Grid Margin="25,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                        <TextBlock Text="MystUtil" FontSize="24" FontWeight="Bold"
                                Foreground="#64B5F6" FontFamily="Segoe UI"/>
                        <TextBlock Text="System Optimization Tool" FontSize="11"
                                Foreground="White" FontFamily="Segoe UI"/>
                    </StackPanel>

                    <Border Grid.Column="1" Background="#1E1E1E" CornerRadius="8" BorderBrush="#3F3F46"
                            BorderThickness="1" Margin="20,0" Width="280" Height="38">
                        <TextBox Name="SearchBox" Background="Transparent" Foreground="#CCCCCC" BorderThickness="0"
                                VerticalContentAlignment="Center" FontSize="13" Text="Search tools..."
                                Padding="15,0" FontFamily="Segoe UI" CaretBrush="#1E1E1E"/>
                    </Border>

                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="15,0">
                        <Border Name="MainTabBorder" Background="#64B5F6" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="0" Style="{StaticResource TabStyle}"
                                Margin="0,0,5,0" Width="100" Height="38">
                            <TextBlock Text="Main Tools" Foreground="White" FontSize="13" FontWeight="SemiBold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"/>
                        </Border>
                        <Border Name="CustomTabBorder" Background="#1E1E1E" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="0" Style="{StaticResource TabStyle}"
                                Margin="0,0,5,0" Width="75" Height="38">
                            <TextBlock Text="Custom" Foreground="White" FontSize="12" FontWeight="SemiBold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"/>
                        </Border>
                        <Border Name="OtherTabBorder" Background="#1E1E1E" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="0" Style="{StaticResource TabStyle}"
                                Width="100" Height="38">
                            <TextBlock Text="Advanced" Foreground="White" FontSize="13" FontWeight="SemiBold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"/>
                        </Border>
                    </StackPanel>

                    <Border Grid.Column="3" Name="CloseButtonBorder" Background="#1E1E1E" CornerRadius="8"
                            BorderBrush="#64B5F6" BorderThickness="2"
                            Width="45" Height="38" Margin="20,0,0,0" Style="{StaticResource CloseButtonStyle}">
                    <TextBlock Text="X" Foreground="#64B5F6" FontSize="16" FontWeight="Bold"
                            HorizontalAlignment="Center" VerticalAlignment="Center"
                            FontFamily="Segoe UI" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display"/>
                    </Border>
                </Grid>
            </Border>

            <ScrollViewer Name="MainScrollViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto"
                        HorizontalScrollBarVisibility="Disabled"
                        Margin="30" Background="#1E1E1E" Style="{StaticResource ModernScrollViewerStyle}">
                <Border Background="#1E1E1E" Padding="30,5,30,15">
                    <Grid Name="MainContentGrid">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="25"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Name="LeftButtonContainer" Grid.Column="0" VerticalAlignment="Top"/>
                        <StackPanel Name="RightButtonContainer" Grid.Column="2" VerticalAlignment="Top"/>
                    </Grid>
                </Border>
            </ScrollViewer>

            <Border Grid.Row="2" Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="0,1,0,0">
                <Grid Margin="25,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Name="StatusText" Grid.Column="0" Text="Ready" Foreground="White"
                            VerticalAlignment="Center" FontSize="12" FontFamily="Segoe UI"/>

                    <TextBlock Grid.Column="1" Text="v2.2 | Running as Administrator" Foreground="#888888"
                            VerticalAlignment="Center" FontSize="10" FontFamily="Segoe UI"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
'@

#===========================================================================
# UI Functions
#===========================================================================

function New-CategoryHeader {
    [CmdletBinding()]
    param([string]$CategoryName)

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $CategoryName
    $header.FontSize = 15
    $header.FontWeight = "SemiBold"
    $header.FontFamily = "Segoe UI"
    $header.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $header.HorizontalAlignment = "Left"
    $header.Margin = "0,0,0,15"
    $header.Padding = "0,8,0,0"

    return $header
}

function New-Button {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Description,
        [string]$Action,
        [string]$Category,
        [string]$Icon = "[?]"
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Height = 50
    $button.Margin = "0,6,0,0"
    $button.Padding = "15,10"
    $button.HorizontalAlignment = "Stretch"
    $button.HorizontalContentAlignment = "Left"
    $button.ToolTip = $Description
    $button.Style = $script:sync.Window.Resources["ModernButtonStyle"]
    $button.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(40, 40, 45))
    $button.Foreground = [System.Windows.Media.Brushes]::White
    $button.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(70, 70, 70))
    $button.BorderThickness = "1"
    $button.Cursor = "Hand"

    $content = New-Object System.Windows.Controls.StackPanel
    $content.Orientation = "Horizontal"
    $content.VerticalAlignment = "Center"

    # Create icon container
    $iconContainer = New-Object System.Windows.Controls.Border
    $iconContainer.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 30, 30))
    $iconContainer.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $iconContainer.BorderThickness = "1"
    $iconContainer.CornerRadius = "4"
    $iconContainer.Width = 32
    $iconContainer.Height = 32
    $iconContainer.Margin = "5,0,12,0"
    $iconContainer.VerticalAlignment = "Center"

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $Icon.Trim('[', ']')
    $iconText.FontSize = 11
    $iconText.FontFamily = "Segoe UI"
    $iconText.FontWeight = "Bold"
    $iconText.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $iconText.HorizontalAlignment = "Center"
    $iconText.VerticalAlignment = "Center"
    $iconText.TextAlignment = "Center"

    $iconContainer.Child = $iconText

    $textContent = New-Object System.Windows.Controls.StackPanel
    $textContent.Orientation = "Vertical"

    $nameText = New-Object System.Windows.Controls.TextBlock
    $nameText.Text = $Name
    $nameText.FontSize = 13
    $nameText.FontFamily = "Segoe UI"
    $nameText.FontWeight = "SemiBold"
    $nameText.VerticalAlignment = "Center"

    $descText = New-Object System.Windows.Controls.TextBlock
    $descText.Text = $Description
    $descText.FontSize = 10
    $descText.FontFamily = "Segoe UI"
    $descText.Foreground = [System.Windows.Media.Brushes]::LightGray
    $descText.TextWrapping = "Wrap"
    $descText.Margin = "0,2,0,0"

    $textContent.Children.Add($nameText) | Out-Null
    $textContent.Children.Add($descText) | Out-Null

    $content.Children.Add($iconContainer) | Out-Null
    $content.Children.Add($textContent) | Out-Null
    $button.Content = $content

    # Store action and add click event
    $button.Tag = $Action
    $button.Add_Click({
            try {
                $actionName = $this.Tag
                Update-Status "Executing: $Name"
                & $actionName
            }
            catch {
                Update-Status "Error executing $Name`: $($_.Exception.Message)" "ERROR"
            }
        })

    return $button
}

function Show-Buttons {
    [CmdletBinding()]
    param([string]$Filter = "")

    $script:sync.LeftButtonContainer.Children.Clear()
    $script:sync.RightButtonContainer.Children.Clear()

    $buttons = $script:ButtonConfig | ForEach-Object {
        [PSCustomObject]@{
            Name        = $_.Name
            Description = $_.Description
            Action      = $_.Action
            Category    = if ($_.Category) { $_.Category } else { "Uncategorized" }
            Icon        = $_.Icon
        }
    }

    if ($script:sync.CurrentFilter -and $script:sync.CurrentFilter.Count -gt 0) {
        $buttons = $buttons | Where-Object { $_.Category -in $script:sync.CurrentFilter }
    }

    if ($Filter) {
        $buttons = $buttons | Where-Object {
            $_.Name -like "*$Filter*" -or $_.Description -like "*$Filter*" -or $_.Category -like "*$Filter*"
        }
    }

    if (!$buttons) {
        $noResults = New-Object System.Windows.Controls.TextBlock
        $noResults.Text = if ($Filter) { "No results found for: '$Filter'" } else { "No tools available in this category" }
        $noResults.FontSize = 16
        $noResults.Foreground = [System.Windows.Media.Brushes]::Gray
        $noResults.HorizontalAlignment = "Center"
        $noResults.Margin = "0,80,0,0"
        $noResults.FontFamily = "Segoe UI"
        $script:sync.LeftButtonContainer.Children.Add($noResults) | Out-Null
        return
    }

    # Group buttons by category and alternate containers
    $categories = $buttons | Group-Object Category | Sort-Object Name
    $leftColumn = $true

    foreach ($category in $categories) {
        $container = if ($leftColumn) { $script:sync.LeftButtonContainer } else { $script:sync.RightButtonContainer }

        # Create and add category header
        $catName = if ($category.Name -ne "") { $category.Name } else { "Uncategorized" }
        $header = New-CategoryHeader -CategoryName $catName

        # First category in each column gets no top margin for alignment
        if ($container.Children.Count -eq 0) {
            $header.Margin = "0,0,0,15"
        }
        else {
            $header.Margin = "0,25,0,15"
        }

        $container.Children.Add($header) | Out-Null

        # Add buttons for this category
        $category.Group | Sort-Object Name | ForEach-Object {
            $btn = New-Button -Name $_.Name -Description $_.Description -Action $_.Action -Category $_.Category -Icon $_.Icon
            $container.Children.Add($btn) | Out-Null
        }

        $leftColumn = !$leftColumn
    }
}

function Set-ActiveTab {
    [CmdletBinding()]
    param([string]$TabName)

    $mainTab = $script:sync.Window.FindName("MainTabBorder")
    $customTab = $script:sync.Window.FindName("CustomTabBorder")
    $otherTab = $script:sync.Window.FindName("OtherTabBorder")
    $activeColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $inactiveColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 30, 30))
    $blueBorderColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))

    # Reset all tabs to inactive
    $mainTab.Background = $inactiveColor
    $mainTab.BorderBrush = $blueBorderColor
    $customTab.Background = $inactiveColor
    $customTab.BorderBrush = $blueBorderColor
    $otherTab.Background = $inactiveColor
    $otherTab.BorderBrush = $blueBorderColor

    if ($TabName -eq "Main") {
        $mainTab.Background = $activeColor
        $mainTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Cleanup", "Install", "System", "Games", "Extras")
    }
    elseif ($TabName -eq "Custom") {
        $customTab.Background = $activeColor
        $customTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Custom")
    }
    elseif ($TabName -eq "Advanced") {
        $otherTab.Background = $activeColor
        $otherTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Advanced")
    }

    Show-Buttons
    $script:sync.Settings.LastTab = $TabName
    Save-Configuration
}

#===========================================================================
# Main Application Initialization
#===========================================================================

function Initialize-UI {
    Write-Log "Initializing UI interface..." -Level "INFO"

    try {
        $script:sync.Window = [Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]([xml]$xaml)))

        $script:sync.LeftButtonContainer = $script:sync.Window.FindName("LeftButtonContainer")
        $script:sync.RightButtonContainer = $script:sync.Window.FindName("RightButtonContainer")
        $script:sync.StatusText = $script:sync.Window.FindName("StatusText")
        $script:sync.SearchBox = $script:sync.Window.FindName("SearchBox")

        # Search functionality
        $searchTimer = New-Object System.Windows.Threading.DispatcherTimer
        $searchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
        $searchTimer.Add_Tick({
                $searchText = $script:sync.SearchBox.Text.Trim()
                if ($searchText -eq "Search tools..." -or [string]::IsNullOrWhiteSpace($searchText)) {
                    Show-Buttons
                }
                else {
                    Show-Buttons -Filter $searchText
                }
                $searchTimer.Stop()
            })

        $script:sync.SearchBox.Add_TextChanged({
                $searchTimer.Stop()
                $searchTimer.Start()
            })

        $script:sync.SearchBox.Add_GotFocus({
                if ($this.Text -eq "Search tools...") {
                    $this.Text = ""
                    $this.Foreground = [System.Windows.Media.Brushes]::White
                }
            })

        $script:sync.SearchBox.Add_LostFocus({
                if ([string]::IsNullOrWhiteSpace($this.Text)) {
                    $this.Text = "Search tools..."
                    $this.Foreground = [System.Windows.Media.Brushes]::Gray
                }
            })

        # Window events
        $script:sync.Window.FindName("DragArea").Add_MouseLeftButtonDown({
                try {
                    $script:sync.Window.DragMove()
                }
                catch {
                    # Ignore drag errors
                }
            })

        $script:sync.Window.FindName("CloseButtonBorder").Add_MouseLeftButtonDown({
                $script:sync.Window.Close()
            })

        $script:sync.Window.FindName("MainTabBorder").Add_MouseLeftButtonDown({
                Set-ActiveTab -TabName "Main"
            })

        $script:sync.Window.FindName("CustomTabBorder").Add_MouseLeftButtonDown({
                Set-ActiveTab -TabName "Custom"
            })

        $script:sync.Window.FindName("OtherTabBorder").Add_MouseLeftButtonDown({
                Set-ActiveTab -TabName "Advanced"
            })

        $script:sync.Window.Add_Closing({
                try {
                    $script:sync.Settings.WindowWidth = [int]$script:sync.Window.ActualWidth
                    $script:sync.Settings.WindowHeight = [int]$script:sync.Window.ActualHeight
                    Save-Configuration
                }
                catch {
                    # Ignore save errors on close
                }
            })

        Set-ActiveTab -TabName $script:sync.Settings.LastTab
        Update-Status "MystUtil ready - $($script:ButtonConfig.Count) tools available"

        Write-Log "UI initialization completed successfully" -Level "INFO"

        $script:sync.Window.ShowDialog() | Out-Null

    }
    catch {
        Write-Log "Failed to initialize UI: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            "Failed to initialize the application interface.`n`nError: $($_.Exception.Message)",
            "Initialization Error",
            "OK",
            "Error"
        )
        throw
    }
}

#===========================================================================
# Application Entry Point
#===========================================================================

Write-Log "Starting MystUtil v2.2..." -Level "INFO"

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