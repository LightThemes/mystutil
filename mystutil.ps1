#Requires -Version 5.1

param (
    [switch]$DebugMode,
    [string]$Config,
    [switch]$Run,
    [switch]$NoSingleInstance
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

$script:sync = [Hashtable]::Synchronized(@{
        LogPath      = Join-Path $env:TEMP "MystUtil.log"
        ConfigPath   = Join-Path $env:APPDATA "MystUtil"
        SettingsFile = Join-Path $env:APPDATA "MystUtil\settings.json"
    })

$script:BlueColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
$script:GrayColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(180, 180, 180))
$script:DarkColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(42, 42, 47))
$script:SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(300)

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
    } catch {
        if ($Level -eq "ERROR") {
            Write-Host "Logging failed: $($_.Exception.Message)" -ForegroundColor Red
        }
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

    if ($script:sync.StatusText) {
        try {
            $script:sync.StatusText.Dispatcher.BeginInvoke([Action] {
                    $script:sync.StatusText.Text = $Message
                    $script:sync.StatusText.Foreground = $script:BlueColor
                }) | Out-Null
        } catch { }
    }

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
}

if ($Host.Name -eq "ConsoleHost") {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"

    try {
        $bufferSize = $Host.UI.RawUI.BufferSize
        $bufferSize.Height = 3000

        $Host.UI.RawUI.BufferSize = $bufferSize

        $windowSize = $Host.UI.RawUI.WindowSize
        if ($windowSize.Width -lt 120) {
            $windowSize.Width = 120
        }
        if ($windowSize.Height -lt 30) {
            $windowSize.Height = 30
        }
        $Host.UI.RawUI.WindowSize = $windowSize
    } catch {}
    Clear-Host
}

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch] -and $_.Value) {
            $arguments += "-$($_.Key)"
        } elseif ($_.Value) {
            $arguments += "-$($_.Key)", "'$($_.Value)'"
        }
    }

    $argumentString = $arguments -join ' '
    $script = "& '$PSCommandPath' $argumentString"
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    exit
}

if (!$NoSingleInstance) {
    Get-Process -Name "powershell*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID -and $_.MainWindowTitle -like "*MystUtil*" } |
    ForEach-Object { $_.CloseMainWindow() }
}

$Host.UI.RawUI.WindowTitle = "MystUtil (Admin)"
Clear-Host

class AppSettings {
    [int]$WindowWidth = 900
    [int]$WindowHeight = 700
    [string]$LastTab = "Main"
    [string]$Theme = "Dark"
}

function Initialize-Configuration {
    $script:sync.CurrentFilter = @("Cleanup", "Install", "System", "Games")

    if (!(Test-Path $script:sync.ConfigPath)) {
        try {
            [System.IO.Directory]::CreateDirectory($script:sync.ConfigPath) | Out-Null
            Write-Log "Created configuration directory: $($script:sync.ConfigPath)" -Level "INFO"
        } catch {
            Write-Log "Failed to create config directory: $($_.Exception.Message)" -Level "WARN"
        }
    }

    try {
        if (Test-Path $script:sync.SettingsFile) {
            $json = [System.IO.File]::ReadAllText($script:sync.SettingsFile)
            $loadedSettings = $json | ConvertFrom-Json
            $script:sync.Settings = [AppSettings]::new()

            if ($loadedSettings.WindowWidth) { $script:sync.Settings.WindowWidth = $loadedSettings.WindowWidth }
            if ($loadedSettings.WindowHeight) { $script:sync.Settings.WindowHeight = $loadedSettings.WindowHeight }
            if ($loadedSettings.LastTab) { $script:sync.Settings.LastTab = $loadedSettings.LastTab }
            if ($loadedSettings.Theme) { $script:sync.Settings.Theme = $loadedSettings.Theme }

            Write-Log "Settings loaded successfully from: $($script:sync.SettingsFile)" -Level "INFO"
        } else {
            $script:sync.Settings = [AppSettings]::new()
            Save-Configuration
            Write-Log "Created default settings file: $($script:sync.SettingsFile)" -Level "INFO"
        }
    } catch {
        $script:sync.Settings = [AppSettings]::new()
        Write-Log "Failed to load settings, using defaults: $($_.Exception.Message)" -Level "WARN"
    }

    if ($script:sync.Settings.LastTab -notin @("Main", "Custom")) {
        $script:sync.Settings.LastTab = "Main"
        Write-Log "Reset invalid LastTab to 'Main'" -Level "INFO"
    }

    Write-Log "Configuration initialized - CurrentFilter: $($script:sync.CurrentFilter -join ', ')" -Level "INFO"
}

function Save-Configuration {
    try {
        $json = $script:sync.Settings | ConvertTo-Json -Depth 2
        [System.IO.File]::WriteAllText($script:sync.SettingsFile, $json)
    } catch {
        Write-Log "Failed to save configuration" -Level "ERROR"
    }
}

function Get-FolderSize {
    param([string]$Path)
    if (![System.IO.Directory]::Exists($Path)) { return 0 }

    try {
        $size = [System.IO.Directory]::EnumerateFiles($Path, "*", "AllDirectories") |
        ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum
        return [math]::Round($size.Sum / 1MB, 2)
    } catch { return 0 }
}

function Remove-ItemsSafely {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$Description,
        [string[]]$ExcludeFiles = @()
    )

    if (![System.IO.Directory]::Exists($Path)) {
        Update-Status "Skipped: $Description (not found)" "WARN"
        return 0
    }

    $sizeBefore = Get-FolderSize -Path $Path

    try {
        $items = @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)

        if ($items.Count -gt 0) {
            $filteredItems = $items

            if ($ExcludeFiles.Count -gt 0) {
                $filteredItems = $items | Where-Object {
                    $fileName = $_.Name
                    $shouldExclude = $false
                    foreach ($excludePattern in $ExcludeFiles) {
                        if ($fileName -like $excludePattern) {
                            $shouldExclude = $true
                            break
                        }
                    }
                    return -not $shouldExclude
                }

                $excludedCount = $items.Count - $filteredItems.Count
                if ($excludedCount -gt 0) {
                    Update-Status "Clearing: $Description ($($filteredItems.Count) items, $excludedCount excluded)..."
                } else {
                    Update-Status "Clearing: $Description ($($filteredItems.Count) items)..."
                }
            } else {
                Update-Status "Clearing: $Description ($($filteredItems.Count) items)..."
            }

            foreach ($item in $filteredItems) {
                try {
                    Remove-Item -Path $item.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
                } catch {}
            }

            if ($ExcludeFiles.Count -gt 0 -and ($items.Count - $filteredItems.Count) -gt 0) {
                Update-Status "Cleared: $Description - $($filteredItems.Count) items (${sizeBefore}MB, troubleshooting files preserved)"
            } else {
                Update-Status "Cleared: $Description - $($filteredItems.Count) items (${sizeBefore}MB)"
            }
        } else {
            Update-Status "Skipped: $Description (empty)"
        }
    } catch {
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
        } else {
            Update-Status "$Name installation completed with exit code: $($process.ExitCode)" "WARN"
        }

        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    } catch {
        Update-Status "Failed to install $Name - $($_.Exception.Message)" "ERROR"
    }
}

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
        if ($tempPath.Path -eq $env:TEMP) {
            $totalFreed += Remove-ItemsSafely -Path $tempPath.Path -Description $tempPath.Name -ExcludeFiles @("MystUtil.log")
        } else {
            $totalFreed += Remove-ItemsSafely -Path $tempPath.Path -Description $tempPath.Name
        }
    }

    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $totalFreed += Remove-ItemsSafely -Path "C:\Windows\SoftwareDistribution\Download" -Description "Windows Update Cache"
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    } catch {
        Update-Status "Could not clean Windows Update cache" "WARN"
    }

    Update-Status "Temp cleanup complete - ${totalFreed}MB freed (MystUtil.log preserved)" "SUCCESS"
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
    } else {
        Update-Status "No VRChat installation found" "WARN"
        Write-Log "No VRChat installation found on system" -Level "WARN"
    }
}

function Remove-VRChatRegistry {
    try {
        Update-Status "Scanning for VRChat registry entries..." "INFO"
        Write-Log "Starting VRChat registry cleanup..." -Level "INFO"

        $registryPaths = @(
            "HKCU:\Software\VRChat",
            "HKLM:\Software\VRChat",
            "HKLM:\Software\WOW6432Node\VRChat",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\VRChat",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\VRChat",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\VRChat"
        )

        $foundEntries = 0
        $removedEntries = 0

        foreach ($regPath in $registryPaths) {
            try {
                if (Test-Path $regPath) {
                    $foundEntries++
                    Update-Status "Removing registry key: $regPath" "INFO"
                    Remove-Item -Path $regPath -Recurse -Force -Confirm:$false -ErrorAction Stop
                    Update-Status "Removed: $regPath" "SUCCESS"
                    Write-Log "Successfully removed registry key: $regPath" -Level "SUCCESS"
                    $removedEntries++
                } else {
                    Write-Log "Registry key not found: $regPath" -Level "INFO"
                }
            } catch {
                Update-Status "Failed to remove: $regPath - $($_.Exception.Message)" "ERROR"
                Write-Log "Failed to remove registry key $regPath`: $($_.Exception.Message)" -Level "ERROR"
            }
        }
        $runKeys = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        )

        foreach ($runKey in $runKeys) {
            try {
                if (Test-Path $runKey) {
                    $runEntries = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
                    if ($runEntries) {
                        $runEntries.PSObject.Properties | Where-Object {
                            $_.Name -like "*VRChat*" -or $_.Value -like "*VRChat*"
                        } | ForEach-Object {
                            try {
                                $foundEntries++
                                Update-Status "Removing startup entry: $($_.Name)" "INFO"
                                Remove-ItemProperty -Path $runKey -Name $_.Name -Force -ErrorAction Stop
                                Update-Status "Removed startup entry: $($_.Name)" "SUCCESS"
                                Write-Log "Removed VRChat startup entry: $($_.Name)" -Level "SUCCESS"
                                $removedEntries++
                            } catch {
                                Update-Status "Failed to remove startup entry: $($_.Name)" "ERROR"
                                Write-Log "Failed to remove startup entry $($_.Name): $($_.Exception.Message)" -Level "ERROR"
                            }
                        }
                    }
                }
            } catch {
                Write-Log "Could not scan run key $runKey`: $($_.Exception.Message)" -Level "WARN"
            }
        }

        if ($foundEntries -eq 0) {
            Update-Status "No VRChat registry entries found" "INFO"
            Write-Log "No VRChat registry entries found on system" -Level "INFO"
        } else {
            $summary = "Registry cleanup complete - found $foundEntries entries, removed $removedEntries"
            Update-Status $summary "SUCCESS"
            Write-Log "VRChat registry cleanup summary: $summary" -Level "SUCCESS"
        }

    } catch {
        Update-Status "VRChat registry cleanup failed: $($_.Exception.Message)" "ERROR"
        Write-Log "VRChat registry cleanup failed: $($_.Exception.Message)" -Level "ERROR"
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
        } else {
            $totalFreed += Remove-ItemsSafely -Path $browser.Path -Description $browser.Name
        }
    }
    Update-Status "Browser cleanup complete - ${totalFreed}MB freed" "SUCCESS"
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
        } catch {
            Update-Status "Failed: $($command.Desc)" "ERROR"
        }
    }

    Update-Status "Network reset complete - restart recommended for full effect"
}

function Clear-RecycleBin {
    try {
        Update-Status "Emptying Recycle Bin..."
        Write-Log "Starting Recycle Bin cleanup..." -Level "INFO"

        $job = Start-Job -ScriptBlock {
            try {
                Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
                return "Success"
            } catch {
                return "Failed: $($_.Exception.Message)"
            }
        }

        $completed = Wait-Job $job -Timeout 10

        if ($completed) {
            $result = Receive-Job $job
            Remove-Job $job

            if ($result -eq "Success") {
                Update-Status "Recycle Bin emptied successfully" "INFO"
                Write-Log "Recycle Bin cleared via PowerShell cmdlet" -Level "INFO"
                return
            }
        } else {
            Remove-Job $job -Force
            Write-Log "PowerShell Clear-RecycleBin timed out, trying alternative method" -Level "WARN"
        }

        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(10)
            if ($recycleBin.Items().Count -gt 0) {
                $recycleBin.Self.InvokeVerb("Empty")
                Start-Sleep -Seconds 2
                Update-Status "Recycle Bin emptied successfully (via COM)" "INFO"
                Write-Log "Recycle Bin cleared via COM object" -Level "INFO"
            } else {
                Update-Status "Recycle Bin is already empty" "INFO"
                Write-Log "Recycle Bin was already empty" -Level "INFO"
            }
        } catch {
            try {
                Write-Log "Trying command line method for Recycle Bin" -Level "INFO"
                $result = cmd /c "rd /s /q C:\`$Recycle.Bin" 2>&1
                Update-Status "Recycle Bin cleared via command line" "INFO"
                Write-Log "Recycle Bin cleared via command line" -Level "INFO"
            } catch {
                Update-Status "Could not empty Recycle Bin - may already be empty or in use" "WARN"
                Write-Log "All Recycle Bin clearing methods failed" -Level "WARN"
            }
        }
    } catch {
        Update-Status "Failed to empty Recycle Bin: $($_.Exception.Message)" "ERROR"
        Write-Log "Recycle Bin cleanup failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Clear-SpotifyCache {
    Update-Status "Starting Spotify cache cleanup..."
    Write-Log "Starting Spotify cache cleanup..." -Level "INFO"

    $spotifyPaths = @(
        "$env:APPDATA\Spotify\Storage",
        "$env:APPDATA\Spotify\Data",
        "$env:APPDATA\Spotify\Browser",
        "$env:LOCALAPPDATA\Spotify\Storage",
        "$env:LOCALAPPDATA\Spotify\Data"
    )

    $totalFreed = 0
    $found = $false

    foreach ($path in $spotifyPaths) {
        if ([System.IO.Directory]::Exists($path)) {
            $found = $true
            $totalFreed += Remove-ItemsSafely -Path $path -Description "Spotify Cache"
        }
    }

    if ($found) {
        Update-Status "Spotify cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
    } else {
        Update-Status "No Spotify installation found" "WARN"
        Write-Log "No Spotify installation found on system" -Level "WARN"
    }
}

function Clear-SteamCache {
    Update-Status "Starting Steam cache cleanup..."
    Write-Log "Starting Steam cache cleanup..." -Level "INFO"

    $steamPaths = @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam",
        "C:\Steam"
    )

    $steamPath = $null
    foreach ($path in $steamPaths) {
        if ([System.IO.Directory]::Exists($path)) {
            $steamPath = $path
            break
        }
    }

    if (!$steamPath) {
        Update-Status "No Steam installation found" "WARN"
        Write-Log "No Steam installation found on system" -Level "WARN"
        return
    }

    $cachePaths = @(
        "$steamPath\appcache",
        "$steamPath\logs",
        "$steamPath\dumps",
        "$steamPath\config\htmlcache"
    )

    $totalFreed = 0
    foreach ($cachePath in $cachePaths) {
        if ([System.IO.Directory]::Exists($cachePath)) {
            $pathName = Split-Path $cachePath -Leaf
            $totalFreed += Remove-ItemsSafely -Path $cachePath -Description "Steam $pathName"
        }
    }

    Update-Status "Steam cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
    Write-Log "Steam cache cleanup completed - ${totalFreed}MB total space freed" -Level "SUCCESS"
}

function Start-DiskCleanup {
    try {
        Update-Status "Running automated disk cleanup..."

        $process = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -PassThru -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Update-Status "Automated disk cleanup completed successfully"
        } else {
            Update-Status "Disk cleanup completed with exit code: $($process.ExitCode)" "WARN"
        }
    } catch {
        Update-Status "Failed to run automated disk cleanup: $($_.Exception.Message)" "ERROR"
    }
}

function Install-7Zip {
    Install-Software -Name "7-Zip" -Url "https://www.7-zip.org/a/7z2301-x64.exe" -Arguments "/S"
}

function Install-WinRAR {
    Install-Software -Name "WinRAR" -Url "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-623.exe" -Arguments "/S"
}

function Install-VSCode {
    Install-Software -Name "VS Code" -Url "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" -Arguments "/VERYSILENT /NORESTART" -FileName "VSCode.exe"
}

function Install-Chrome {
    Install-Software -Name "Chrome" -Url "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi" -Arguments "/quiet /norestart" -FileName "Chrome.msi"
}

function Install-Spotify {
    Install-Software -Name "Spotify" -Url "https://download.scdn.co/SpotifySetup.exe" -Arguments "/silent" -FileName "SpotifySetup.exe"
}

function Install-Steam {
    Install-Software -Name "Steam" -Url "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -Arguments "/S" -FileName "SteamSetup.exe"
}

function Start-SFCScan {
    try {
        Update-Status "Starting System File Checker scan (this may take several minutes)..." "INFO"
        Write-Log "SFC scan initiated" -Level "INFO"

        $job = Start-Job -ScriptBlock {
            $process = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $env:TEMP\sfc_output.txt
            return @{
                ExitCode = $process.ExitCode
                Output   = if (Test-Path "$env:TEMP\sfc_output.txt") { Get-Content "$env:TEMP\sfc_output.txt" -Raw } else { "" }
            }
        }

        $elapsed = 0
        while ($job.State -eq "Running") {
            Start-Sleep -Seconds 10
            $elapsed += 10
            $minutes = [math]::Floor($elapsed / 60)
            $seconds = $elapsed % 60
            Update-Status "SFC scan in progress... (${minutes}m ${seconds}s elapsed)" "INFO"
        }

        $result = Receive-Job -Job $job -Wait
        Remove-Job -Job $job

        $exitCode = $result.ExitCode
        $totalMinutes = [math]::Floor($elapsed / 60)
        $totalSeconds = $elapsed % 60

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

        Start-Sleep -Seconds 2

    } catch {
        Update-Status "Failed to run SFC scan: $($_.Exception.Message)" "ERROR"
        Write-Log "SFC scan failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Start-DISMScan {
    try {
        Update-Status "Starting DISM health scan (this may take several minutes)..." "INFO"
        Write-Log "DISM health scan initiated" -Level "INFO"
        Update-Status "DISM: Checking Windows image health..." "INFO"

        $checkJob = Start-Job -ScriptBlock {
            $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online", "/cleanup-image", "/checkhealth" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\dism_check.txt" -RedirectStandardError "$env:TEMP\dism_check_error.txt"
            return @{
                ExitCode = $process.ExitCode
                Output   = if (Test-Path "$env:TEMP\dism_check.txt") { Get-Content "$env:TEMP\dism_check.txt" -Raw } else { "" }
                Error    = if (Test-Path "$env:TEMP\dism_check_error.txt") { Get-Content "$env:TEMP\dism_check_error.txt" -Raw } else { "" }
            }
        }

        $checkResult = Receive-Job -Job $checkJob -Wait
        Remove-Job -Job $checkJob

        if ($checkResult.ExitCode -eq 0) {
            Update-Status "DISM: Image health check completed - no issues detected" "SUCCESS"
            Write-Log "DISM health check completed successfully - no corruption found" -Level "SUCCESS"
        } else {
            Update-Status "DISM: Issues detected, proceeding with scan and repair..." "WARN"
            Write-Log "DISM health check found issues - starting scan and repair" -Level "WARN"

            Update-Status "DISM: Scanning Windows image for corruption..." "INFO"
            $scanJob = Start-Job -ScriptBlock {
                $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online", "/cleanup-image", "/scanhealth" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\dism_scan.txt" -RedirectStandardError "$env:TEMP\dism_scan_error.txt"
                return @{
                    ExitCode = $process.ExitCode
                    Output   = if (Test-Path "$env:TEMP\dism_scan.txt") { Get-Content "$env:TEMP\dism_scan.txt" -Raw } else { "" }
                    Error    = if (Test-Path "$env:TEMP\dism_scan_error.txt") { Get-Content "$env:TEMP\dism_scan_error.txt" -Raw } else { "" }
                }
            }

            $elapsed = 0
            while ($scanJob.State -eq "Running") {
                Start-Sleep -Seconds 15
                $elapsed += 15
                $minutes = [math]::Floor($elapsed / 60)
                $seconds = $elapsed % 60
                Update-Status "DISM: Scanning image health... (${minutes}m ${seconds}s elapsed)" "INFO"
            }

            $scanResult = Receive-Job -Job $scanJob -Wait
            Remove-Job -Job $scanJob

            if ($scanResult.ExitCode -eq 0) {
                Update-Status "DISM: Starting image repair process..." "INFO"
                Write-Log "DISM scan completed - starting repair process" -Level "INFO"

                $repairJob = Start-Job -ScriptBlock {
                    $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online", "/cleanup-image", "/restorehealth" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\dism_repair.txt" -RedirectStandardError "$env:TEMP\dism_repair_error.txt"
                    return @{
                        ExitCode = $process.ExitCode
                        Output   = if (Test-Path "$env:TEMP\dism_repair.txt") { Get-Content "$env:TEMP\dism_repair.txt" -Raw } else { "" }
                        Error    = if (Test-Path "$env:TEMP\dism_repair_error.txt") { Get-Content "$env:TEMP\dism_repair_error.txt" -Raw } else { "" }
                    }
                }

                $repairElapsed = 0
                while ($repairJob.State -eq "Running") {
                    Start-Sleep -Seconds 20
                    $repairElapsed += 20
                    $minutes = [math]::Floor($repairElapsed / 60)
                    $seconds = $repairElapsed % 60
                    Update-Status "DISM: Repairing Windows image... (${minutes}m ${seconds}s elapsed)" "INFO"
                }

                $repairResult = Receive-Job -Job $repairJob -Wait
                Remove-Job -Job $repairJob

                $totalMinutes = [math]::Floor(($elapsed + $repairElapsed) / 60)
                $totalSeconds = ($elapsed + $repairElapsed) % 60

                if ($repairResult.ExitCode -eq 0) {
                    Update-Status "DISM: Image repair completed successfully (${totalMinutes}m ${totalSeconds}s)" "SUCCESS"
                    Write-Log "DISM repair completed successfully in ${totalMinutes}m ${totalSeconds}s" -Level "SUCCESS"
                } else {
                    Update-Status "DISM: Repair completed with warnings (${totalMinutes}m ${totalSeconds}s)" "WARN"
                    Write-Log "DISM repair completed with exit code: $($repairResult.ExitCode) in ${totalMinutes}m ${totalSeconds}s" -Level "WARN"
                }
            } else {
                Update-Status "DISM: Scan failed with exit code: $($scanResult.ExitCode)" "ERROR"
                Write-Log "DISM scan failed with exit code: $($scanResult.ExitCode)" -Level "ERROR"
            }
        }

        @("$env:TEMP\dism_check.txt", "$env:TEMP\dism_check_error.txt", "$env:TEMP\dism_scan.txt", "$env:TEMP\dism_scan_error.txt", "$env:TEMP\dism_repair.txt", "$env:TEMP\dism_repair_error.txt") | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
        }

    } catch {
        Update-Status "Failed to run DISM scan: $($_.Exception.Message)" "ERROR"
        Write-Log "DISM scan failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Clear-DNSCache {
    try {
        Clear-DnsClientCache
        Update-Status "DNS cache flushed successfully"
    } catch {
        Update-Status "Failed to flush DNS cache: $($_.Exception.Message)" "ERROR"
    }
}

function Invoke-CustomMaintenance {
    param([string]$PersonName)

    try {
        Update-Status "$PersonName's custom maintenance is starting..." "INFO"
        Write-Log "Starting $PersonName's personalized system cleanup routine." -Level "INFO"

        Update-Status "Phase 1/4: Starting quick cleanup tasks..." "INFO"
        Clear-TempFiles
        Clear-BrowserCache
        Clear-DNSCache
        Reset-NetworkStack
        Clear-VRChatData
        Clear-RecycleBin

        Update-Status "Phase 2/4: Starting comprehensive system scans..." "INFO"
        Start-SFCScan

        Update-Status "Phase 3/4: Starting driver analysis..." "INFO"
        Start-DriverCheck

        Update-Status "Phase 4/4: Starting final system cleanup..." "INFO"
        Start-DiskCleanup

        Update-Status "All phases complete! $PersonName's maintenance finished successfully!" "SUCCESS"
    } catch {
        Update-Status "$PersonName's maintenance failed: $($_.Exception.Message)" "ERROR"
    }
}

function Invoke-YureiMaintenance { Invoke-CustomMaintenance -PersonName "Yurei" }
function Invoke-MystMaintenance { Invoke-CustomMaintenance -PersonName "Myst" }

function Start-Debloat {
    Update-Status "Checking removable packages..." "INFO"
    Write-Log "Starting debloat process..." -Level "INFO"

    $bloatware = @(
        "Microsoft.ZuneVideo",
        "Microsoft.3DViewer",
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.BingFinance",
        "Microsoft.BingSports",
        "Microsoft.MSNWeather",
        "Microsoft.People",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.YourPhone",
        "Microsoft.CrossDevice",
        "Microsoft.GamingServices",
        "Microsoft.QuickAssist",
        "Microsoft.windowscommunicationsapps",
        "Microsoft.WindowsInkWorkspace",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.Paint",
        "Microsoft.Todos"
    )

    $allPackages = Get-AppxPackage -AllUsers

    $removed = 0
    $notFound = 0
    $systemProtected = 0

    foreach ($app in $bloatware) {
        $packages = $allPackages | Where-Object { $_.Name -like "*$app*" }

        if ($packages) {
            foreach ($package in $packages) {
                if ($package.NonRemovable -eq $true) {
                    Update-Status "System Protected: $($package.Name)" "WARN"
                    Write-Log "System protected app: $($package.Name)" -Level "WARN"
                    $systemProtected++
                    continue
                }
                try {
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                    Update-Status "Removed: $($package.Name)" "SUCCESS"
                    Write-Log "Removed: $($package.Name)" -Level "SUCCESS"
                    $removed++
                } catch {
                    Update-Status "Failed to remove: $($package.Name) - $($_.Exception.Message)" "ERROR"
                    Write-Log "Failed to remove: $($package.Name) - $($_.Exception.Message)" -Level "ERROR"
                }
            }
        } else {
            Update-Status "Not found: $app" "INFO"
            Write-Log "Not found: $app" -Level "INFO"
            $notFound++
        }
    }

    $summary = "Removed: $removed apps | Not found: $notFound apps | System Protected: $systemProtected apps"
    Update-Status "Debloat complete. $summary" "SUCCESS"
    Write-Log "Debloat summary: $summary" -Level "SUCCESS"
}

# Code 28 = Device doesn't have drivers installed // Other error codes indicate driver problems
function Start-DriverCheck {
    try {
        Update-Status "Starting comprehensive driver analysis..." "INFO"
        Write-Log "Scanning Device Manager for driver issues..." -Level "INFO"

        $allDevices = Get-WmiObject -Class Win32_PnPEntity -ErrorAction SilentlyContinue

        if (!$allDevices) {
            Update-Status "Could not retrieve device information" "ERROR"
            return
        }

        $unknownDevices = @()
        $problemDevices = @()
        $workingDevices = @()

        foreach ($device in $allDevices) {
            if ($device.ConfigManagerErrorCode -eq 28) {
                $unknownDevices += $device
            } elseif ($device.ConfigManagerErrorCode -ne 0) {
                $problemDevices += $device
            } elseif ($device.Status -eq "OK") {
                $workingDevices += $device
            }
        }
        Write-Log "Found $($allDevices.Count) total devices, $($unknownDevices.Count) unknown, $($problemDevices.Count) with issues" -Level "INFO"

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
        } else {
            Update-Status "Driver analysis complete - found $($unknownDevices.Count + $problemDevices.Count) driver issues" "WARN"
            Write-Log "Driver analysis completed with issues found" -Level "WARN"
        }

    } catch {
        Update-Status "Failed to analyze drivers: $($_.Exception.Message)" "ERROR"
        Write-Log "Driver analysis failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

$script:ButtonConfig = @(
    @{ Name = "Empty Recycle Bin"; Description = "Permanently deletes all items in Recycle Bin"; Action = "Clear-RecycleBin"; Category = "Cleanup"; Icon = "[BIN]" },
    @{ Name = "Clear Temp Files"; Description = "Comprehensive cleanup of temporary files and caches"; Action = "Clear-TempFiles"; Category = "Cleanup"; Icon = "[DEL]" },
    @{ Name = "Clear Browser Cache"; Description = "Removes cache files from all major browsers"; Action = "Clear-BrowserCache"; Category = "Cleanup"; Icon = "[WEB]" },
    @{ Name = "Clear Spotify Cache"; Description = "Clears Spotify cache and temporary data"; Action = "Clear-SpotifyCache"; Category = "Cleanup"; Icon = "[SPT]" },
    @{ Name = "Clear Steam Cache"; Description = "Clears Steam cache, logs, and temporary files"; Action = "Clear-SteamCache"; Category = "Cleanup"; Icon = "[STM]" },

    @{ Name = "Install 7-Zip"; Description = "Downloads and installs 7-Zip file archiver"; Action = "Install-7Zip"; Category = "Install"; Icon = "[ZIP]" },
    @{ Name = "Install VS Code"; Description = "Downloads and installs Visual Studio Code editor"; Action = "Install-VSCode"; Category = "Install"; Icon = "[IDE]" },
    @{ Name = "Install Chrome"; Description = "Downloads and installs Google Chrome browser"; Action = "Install-Chrome"; Category = "Install"; Icon = "[CHR]" },
    @{ Name = "Install WinRAR"; Description = "Downloads and installs WinRAR file archiver"; Action = "Install-WinRAR"; Category = "Install"; Icon = "[RAR]" },
    @{ Name = "Install Spotify"; Description = "Downloads and installs Spotify music player"; Action = "Install-Spotify"; Category = "Install"; Icon = "[SPT]" },
    @{ Name = "Install Steam"; Description = "Downloads and installs Steam gaming platform"; Action = "Install-Steam"; Category = "Install"; Icon = "[STM]" },

    @{ Name = "System File Checker"; Description = "Runs SFC scan to check system file integrity"; Action = "Start-SFCScan"; Category = "System"; Icon = "[SFC]" },
    @{ Name = "DISM Health Scan"; Description = "Scans and repairs Windows system image corruption"; Action = "Start-DISMScan"; Category = "System"; Icon = "[DISM]" },
    @{ Name = "Driver Check"; Description = "Scans for missing or problematic device drivers"; Action = "Start-DriverCheck"; Category = "System"; Icon = "[DRV]" },
    @{ Name = "Flush DNS Cache"; Description = "Clears DNS resolver cache"; Action = "Clear-DNSCache"; Category = "System"; Icon = "[DNS]" },
    @{ Name = "Network Reset"; Description = "Resets network stack and TCP/IP configuration"; Action = "Reset-NetworkStack"; Category = "System"; Icon = "[NET]" },
    @{ Name = "Disk Cleanup Tool"; Description = "Opens Windows built-in Disk Cleanup utility"; Action = "Start-DiskCleanup"; Category = "System"; Icon = "[DSK]" },
    @{ Name = "Debloat System"; Description = "Removes unnecessary Windows bloatware"; Action = "Start-Debloat"; Category = "System"; Icon = "[DBLT]" },

    @{ Name = "Clear VRChat Data"; Description = "Clears VRChat cache, logs, and temporary data"; Action = "Clear-VRChatData"; Category = "Games"; Icon = "[VRC]" },
    @{ Name = "Remove VRChat Registry"; Description = "Removes VRChat registry keys and startup entries"; Action = "Remove-VRChatRegistry"; Category = "Games"; Icon = "[VRC]" },

    @{ Name = "Yurei"; Description = "For Yurei"; Action = "Invoke-YureiMaintenance"; Category = "Custom"; Icon = "[TEST]" },
    @{ Name = "Myst"; Description = "For Myst"; Action = "Invoke-MystMaintenance"; Category = "Custom"; Icon = "[TEST]" }
)

$script:ButtonCount = $script:ButtonConfig.Count

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
                                CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                                            Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#4A4A52"/>
                                <Setter Property="BorderBrush" Value="#64B5F6"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#52525A"/>
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
                            <ScrollContentPresenter Grid.Column="0"/>
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

        <Style x:Key="StandardBorderStyle" TargetType="Border">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="CornerRadius" Value="8"/>
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
                            </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                        <TextBlock Text="MystUtil" FontSize="24" FontWeight="Bold"
                                Foreground="#64B5F6" FontFamily="Segoe UI"/>
                        <TextBlock Text="A System Optimization Tool" FontSize="11" FontWeight="Bold"
                                Foreground="White" FontFamily="Segoe UI"/>
                    </StackPanel>

                    <Border Grid.Column="1" Background="#1E1E1E" CornerRadius="8" BorderBrush="#3F3F46"
                            BorderThickness="1" Margin="20,0" Width="280" Height="38">
                        <TextBox Name="SearchBox" Background="Transparent" Foreground="#64B5F6" BorderThickness="0"
                                VerticalContentAlignment="Center" FontSize="13" Text="Search tools..."
                                Padding="15,0" FontFamily="Segoe UI" CaretBrush="#64B5F6"/>
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

                        <Border Name="CloseButtonBorder" Background="#1E1E1E" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="2"
                                Width="45" Height="38" Margin="20,0,0,0" Style="{StaticResource CloseButtonStyle}">
                            <TextBlock Text="✕" Foreground="#64B5F6" FontSize="16" FontWeight="Bold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center"
                                    FontFamily="Segoe UI" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </Border>

            <ScrollViewer Name="MainScrollViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto"
                        HorizontalScrollBarVisibility="Disabled"
                        Margin="40" Background="#1E1E1E" Style="{StaticResource ModernScrollViewerStyle}">
                <Border Background="#1E1E1E" Padding="40,20,40,30">
                <Grid Name="MainContentGrid">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Name="LeftButtonContainer" VerticalAlignment="Top"/>
                </Grid>
                </Border>
            </ScrollViewer>

            <Border Grid.Row="2" Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="0,1,0,0">
                <Grid Margin="25,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Name="StatusText" Grid.Column="0" Text="" Foreground="#64B5F6"
                            VerticalAlignment="Center" FontSize="12" FontFamily="Segoe UI" FontWeight="Bold"/>

                    <TextBlock Grid.Column="1" Text="version: 4.3.2" Foreground="#64B5F6"
                            VerticalAlignment="Center" FontSize="12" FontFamily="Segoe UI" FontWeight="Bold"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
'@

function New-CategoryHeader {
    [CmdletBinding()]
    param([string]$CategoryName)

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $CategoryName
    $header.FontSize = 16
    $header.FontWeight = "Bold"
    $header.FontFamily = "Segoe UI"
    $header.Foreground = $script:BlueColor
    $header.HorizontalAlignment = "Left"
    $header.Margin = "0,25,0,20"
    $header.Padding = "0,12,0,8"

    return $header
}

function New-Button {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Description,
        [string]$Action,
        [string]$Icon = "[?]"
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Height = 65
    $button.Margin = "0,8,0,0"
    $button.Padding = "20,12"
    $button.HorizontalAlignment = "Stretch"
    $button.HorizontalContentAlignment = "Left"
    $button.ToolTip = $Description
    $button.Style = $script:sync.Window.Resources["ModernButtonStyle"]
    $button.Background = $script:DarkColor
    $button.Foreground = [System.Windows.Media.Brushes]::White
    $button.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(75, 75, 75))
    $button.BorderThickness = "1"
    $button.Cursor = "Hand"

    $content = New-Object System.Windows.Controls.StackPanel
    $content.Orientation = "Horizontal"
    $content.VerticalAlignment = "Center"

    $iconContainer = New-Object System.Windows.Controls.Border
    $iconContainer.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(28, 28, 30))
    $iconContainer.BorderBrush = $script:BlueColor
    $iconContainer.BorderThickness = "1.5"
    $iconContainer.CornerRadius = "6"
    $iconContainer.Width = 38
    $iconContainer.Height = 38
    $iconContainer.Margin = "8,0,18,0"
    $iconContainer.VerticalAlignment = "Center"

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $Icon.Trim('[', ']')
    $iconText.FontSize = 12
    $iconText.FontFamily = "Segoe UI"
    $iconText.FontWeight = "Bold"
    $iconText.Foreground = $script:BlueColor
    $iconText.HorizontalAlignment = "Center"
    $iconText.VerticalAlignment = "Center"
    $iconText.TextAlignment = "Center"

    $iconContainer.Child = $iconText

    $textContent = New-Object System.Windows.Controls.StackPanel
    $textContent.Orientation = "Vertical"
    $textContent.VerticalAlignment = "Center"

    $nameText = New-Object System.Windows.Controls.TextBlock
    $nameText.Text = $Name
    $nameText.FontSize = 14
    $nameText.FontFamily = "Segoe UI"
    $nameText.FontWeight = "SemiBold"
    $nameText.VerticalAlignment = "Center"
    $nameText.Margin = "0,0,0,4"

    $descText = New-Object System.Windows.Controls.TextBlock
    $descText.Text = $Description
    $descText.FontSize = 11
    $descText.FontFamily = "Segoe UI"
    $descText.Foreground = $script:GrayColor
    $descText.TextWrapping = "Wrap"
    $descText.LineHeight = 16

    $textContent.Children.Add($nameText) | Out-Null
    $textContent.Children.Add($descText) | Out-Null

    $content.Children.Add($iconContainer) | Out-Null
    $content.Children.Add($textContent) | Out-Null
    $button.Content = $content

    $button.Tag = $Action
    $button.Add_Click({
            try {
                $actionName = $this.Tag
                Update-Status "Executing: $Name"
                & $actionName
            } catch {
                Update-Status "Error executing $Name`: $($_.Exception.Message)" "ERROR"
            }
        })

    return $button
}

function Show-Buttons {
    [CmdletBinding()]
    param([string]$Filter = "")

    $script:sync.LeftButtonContainer.Children.Clear()

    $buttons = $script:ButtonConfig | Where-Object {
        ($script:sync.CurrentFilter -contains $_.Category) -and
        ([string]::IsNullOrWhiteSpace($Filter) -or $Filter -eq "Search tools..." -or
        $_.Name -eq $Filter -or $_.Description -eq $Filter -or
        $_.Name -like "*$Filter*" -or $_.Description -like "*$Filter*"
    ) }

    if ($buttons.Count -eq 0) {
        $noButtonsText = New-Object System.Windows.Controls.TextBlock
        $noButtonsText.Text = if ($Filter -and $Filter -ne "Search tools...") { "No tools found matching '$Filter'" } else { "No tools available in this category" }
        $noButtonsText.FontSize = 16
        $noButtonsText.Foreground = [System.Windows.Media.Brushes]::Gray
        $noButtonsText.HorizontalAlignment = "Center"
        $noButtonsText.VerticalAlignment = "Center"
        $noButtonsText.Margin = "20"

        $script:sync.LeftButtonContainer.Children.Add($noButtonsText) | Out-Null
        return
    }

    $groupedButtons = @{}
    $categoryOrder = @()

    foreach ($button in $buttons) {
        if (-not $groupedButtons.ContainsKey($button.Category)) {
            $groupedButtons[$button.Category] = @()
            $categoryOrder += $button.Category
        }
        $groupedButtons[$button.Category] += $button
    }

    $categoryPriority = @{
        "Cleanup" = 1
        "Install" = 2
        "System"  = 3
        "Games"   = 4
        "Custom"  = 5
    }

    $categoryOrder = $categoryOrder | Sort-Object {
        if ($categoryPriority.ContainsKey($_)) {
            $categoryPriority[$_]
        } else {
            999
        }
    }

    foreach ($category in $categoryOrder) {
        $categoryButtons = $groupedButtons[$category]
        $categoryButtons = $categoryButtons | Sort-Object Name
        $header = New-CategoryHeader -CategoryName $category
        $script:sync.LeftButtonContainer.Children.Add($header) | Out-Null
        foreach ($config in $categoryButtons) {
            $button = New-Button -Name $config.Name -Description $config.Description -Action $config.Action -Icon $config.Icon
            $script:sync.LeftButtonContainer.Children.Add($button) | Out-Null
        }
    }
}

function Set-ActiveTab {
    [CmdletBinding()]
    param([string]$TabName)

    $mainTab = $script:sync.Window.FindName("MainTabBorder")
    $customTab = $script:sync.Window.FindName("CustomTabBorder")
    $activeColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $inactiveColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 30, 30))
    $blueBorderColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))

    $mainTab.Background = $inactiveColor
    $mainTab.BorderBrush = $blueBorderColor
    $customTab.Background = $inactiveColor
    $customTab.BorderBrush = $blueBorderColor

    if ($TabName -eq "Main") {
        $mainTab.Background = $activeColor
        $mainTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Cleanup", "Install", "System", "Games")
    } elseif ($TabName -eq "Custom") {
        $customTab.Background = $activeColor
        $customTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Custom")
    }

    Show-Buttons
    $script:sync.Settings.LastTab = $TabName
    Save-Configuration
}
function Initialize-UI {
    Write-Log "Initializing UI interface..." -Level "INFO"

    try {
        $script:sync.Window = [Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]([xml]$xaml)))

        $script:sync.LeftButtonContainer = $script:sync.Window.FindName("LeftButtonContainer")
        $script:sync.StatusText = $script:sync.Window.FindName("StatusText")
        $script:sync.SearchBox = $script:sync.Window.FindName("SearchBox")

        $script:SearchTimer.Add_Tick({
                $searchText = $script:sync.SearchBox.Text.Trim()
                if ($searchText -eq "Search tools..." -or [string]::IsNullOrWhiteSpace($searchText)) {
                    Show-Buttons
                } else {
                    Show-Buttons -Filter $searchText
                }
                $script:SearchTimer.Stop()
            })

        $script:sync.SearchBox.Add_TextChanged({
                $script:SearchTimer.Stop()
                $script:SearchTimer.Start()
            })

        $script:sync.SearchBox.Add_KeyDown({
                if ($_.Key -eq "Return") {
                    $searchText = $script:sync.SearchBox.Text.Trim()
                    if ($searchText -eq "Search tools..." -or [string]::IsNullOrWhiteSpace($searchText)) {
                        Show-Buttons
                    } else {
                        Show-Buttons -Filter $searchText
                    }
                    $_.Handled = $true
                }
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
                    $this.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(100, 181, 246))
                }
            })

        $script:sync.Window.FindName("DragArea").Add_MouseLeftButtonDown({
                try {
                    $script:sync.Window.DragMove()
                } catch {
                    Write-Log "Window drag failed: $($_.Exception.Message)" -Level "DEBUG"
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

        $script:sync.Window.Add_Closing({
                try {
                    $script:sync.Settings.WindowWidth = [int]$script:sync.Window.ActualWidth
                    $script:sync.Settings.WindowHeight = [int]$script:sync.Window.ActualHeight
                    Save-Configuration
                } catch { }
            })

        Set-ActiveTab -TabName $script:sync.Settings.LastTab
        Update-Status "MystUtil ready - $($script:ButtonCount) tools available"

        Write-Log "UI initialization completed successfully" -Level "INFO"

        $script:sync.Window.ShowDialog() | Out-Null

    } catch {
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

Write-Log "MystUtil - Starting..." -Level "INFO"
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host " MystUtil - A System Optimization Tool" -ForegroundColor Cyan
Write-Host " https://github.com/LightThemes/mystutil" -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Log "Initializing configuration..." -Level "INFO"
Initialize-Configuration

try {
    Initialize-UI
} catch {
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
