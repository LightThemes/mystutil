function Invoke-Function {
    param([string]$FunctionName)

    try {
        & $FunctionName
    } catch {
        Update-Status "Function $FunctionName failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Function execution failed for {$FunctionName}: ${_}.Exception.Message" -Level "ERROR"
    }
}

function Install-Software {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$WingetId,
        [string]$FallbackUrl = "",
        [string]$FallbackArgs = ""
    )

    Update-Status "Preparing to install $Name..."

    try {
        $installed = winget list --id $WingetId --exact 2>$null
        if ($LASTEXITCODE -eq 0 -and $installed -match $WingetId) {
            Update-Status "$Name is already installed" "INFO"
            return
        }
    } catch {
        Write-Log "Could not check if $Name is installed: $($_.Exception.Message)" -Level "WARN"
    }

    try {
        Update-Status "Installing $Name via winget..."
        Write-Log "Installing $Name with winget ID: $WingetId" -Level "INFO"

        $null = winget install --id $WingetId --exact --silent --accept-package-agreements --accept-source-agreements 2>&1

        if ($LASTEXITCODE -eq 0) {
            Update-Status "$Name installed successfully via winget" "SUCCESS"
            Write-Log "$Name installation completed via winget" -Level "SUCCESS"
            return
        } else {
            Update-Status "Winget installation failed, trying fallback method..." "WARN"
            Write-Log "Winget failed for $Name (exit code: $LASTEXITCODE), trying fallback" -Level "WARN"
        }
    } catch {
        Update-Status "Winget installation failed: $($_.Exception.Message)" "WARN"
        Write-Log "Winget installation failed for ${Name}: $($_.Exception.Message)" -Level "WARN"
    }

    if ($FallbackUrl) {
        try {
            Update-Status "Downloading $Name from fallback URL..."
            $fileName = "$($Name -replace ' ', '_')-installer.exe"
            $installerPath = Join-Path $env:TEMP $fileName

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($FallbackUrl, $installerPath)
            $webClient.Dispose()

            Update-Status "Installing $Name via direct download..."
            $process = Start-Process -FilePath $installerPath -ArgumentList $FallbackArgs -PassThru -Wait -WindowStyle Hidden

            if ($process.ExitCode -eq 0) {
                Update-Status "$Name installed successfully via fallback" "SUCCESS"
            } else {
                Update-Status "$Name installation completed with exit code: $($process.ExitCode)" "WARN"
            }

            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        } catch {
            Update-Status "Failed to install $Name via fallback: $($_.Exception.Message)" "ERROR"
            Write-Log "Fallback installation failed for ${Name}: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Update-Status "No fallback method available for $Name" "ERROR"
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

function Clear-BrowserCache {
    Update-Status "Starting browser cache cleanup..."

    $browsers = @(
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache*" },
        @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache*" },
        @{ Name = "Firefox"; Path = "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache*" }
    )

    $totalFreed = 0
    foreach ($browser in $browsers) {
        $paths = Get-ChildItem -Path $browser.Path -Directory -ErrorAction SilentlyContinue
        foreach ($path in $paths) {
            $totalFreed += Remove-ItemsSafely -Path $path.FullName -Description "$($browser.Name) Cache"
        }
    }

    Update-Status "Browser cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Clear-RecycleBin {
    Update-Status "Emptying Recycle Bin..."

    try {
        $Shell = New-Object -ComObject Shell.Application
        $RecycleBin = $Shell.Namespace(0xA)
        $RecycleBin.Self.InvokeVerb("Empty Recycle Bin")
        Update-Status "Recycle Bin emptied successfully" "SUCCESS"
    } catch {
        Update-Status "Failed to empty Recycle Bin: $($_.Exception.Message)" "ERROR"
    }
}

function Clear-SpotifyCache {
    Update-Status "Clearing Spotify cache and data..."

    $spotifyPaths = @(
        "$env:APPDATA\Spotify\Data",
        "$env:APPDATA\Spotify\Browser\Cache",
        "$env:APPDATA\Spotify\Storage"
    )

    $totalFreed = 0
    foreach ($path in $spotifyPaths) {
        $totalFreed += Remove-ItemsSafely -Path $path -Description "Spotify Cache"
    }

    Update-Status "Spotify cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Clear-SteamCache {
    Update-Status "Clearing Steam cache and temporary files..."

    $steamPaths = @(
        "$env:PROGRAMFILES(X86)\Steam\appcache",
        "$env:PROGRAMFILES(X86)\Steam\logs",
        "$env:PROGRAMFILES(X86)\Steam\dumps"
    )

    $totalFreed = 0
    foreach ($path in $steamPaths) {
        $totalFreed += Remove-ItemsSafely -Path $path -Description "Steam Cache"
    }

    Update-Status "Steam cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Clear-VRChatData {
    Update-Status "Clearing VRChat cache and temporary data..."

    $vrchatPaths = @(
        "$env:APPDATA\..\LocalLow\VRChat\VRChat\Cache-WindowsPlayer",
        "$env:APPDATA\..\LocalLow\VRChat\VRChat\Logs",
        "$env:TEMP\VRChat"
    )

    $totalFreed = 0
    foreach ($path in $vrchatPaths) {
        $totalFreed += Remove-ItemsSafely -Path $path -Description "VRChat Data"
    }

    Update-Status "VRChat cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Install-7Zip {
    Install-Software -Name "7-Zip" -WingetId "7zip.7zip" -FallbackUrl "https://www.7-zip.org/a/7z2301-x64.exe" -FallbackArgs "/S"
}

function Install-VSCode {
    Install-Software -Name "VS Code" -WingetId "Microsoft.VisualStudioCode" -FallbackUrl "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" -FallbackArgs "/VERYSILENT /NORESTART"
}

function Install-Chrome {
    Install-Software -Name "Google Chrome" -WingetId "Google.Chrome" -FallbackUrl "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi" -FallbackArgs "/quiet /norestart"
}

function Install-WinRAR {
    Install-Software -Name "WinRAR" -WingetId "RARLab.WinRAR" -FallbackUrl "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-623.exe" -FallbackArgs "/S"
}

function Install-Spotify {
    Install-Software -Name "Spotify" -WingetId "Spotify.Spotify" -FallbackUrl "https://download.scdn.co/SpotifySetup.exe" -FallbackArgs "/silent"
}

function Install-Steam {
    Install-Software -Name "Steam" -WingetId "Valve.Steam" -FallbackUrl "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -FallbackArgs "/S"
}

function Start-SFCScan {
    Update-Status "Running System File Checker scan..."

    try {
        $process = Start-Process -FilePath "sfc" -ArgumentList "/scannow" -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Update-Status "SFC scan completed successfully" "SUCCESS"
        } else {
            Update-Status "SFC scan completed with issues (exit code: $($process.ExitCode))" "WARN"
        }
    } catch {
        Update-Status "SFC scan failed: $($_.Exception.Message)" "ERROR"
    }
}

function Start-DISMScan {
    Update-Status "Running DISM health scan..."

    try {
        $process = Start-Process -FilePath "dism" -ArgumentList "/online /cleanup-image /scanhealth" -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Update-Status "DISM scan completed successfully" "SUCCESS"
        } else {
            Update-Status "DISM scan found issues - running repair..." "WARN"
            $repairProcess = Start-Process -FilePath "dism" -ArgumentList "/online /cleanup-image /restorehealth" -PassThru -Wait -WindowStyle Hidden
            if ($repairProcess.ExitCode -eq 0) {
                Update-Status "DISM repair completed successfully" "SUCCESS"
            } else {
                Update-Status "DISM repair completed with issues (exit code: $($repairProcess.ExitCode))" "WARN"
            }
        }
    } catch {
        Update-Status "DISM scan failed: $($_.Exception.Message)" "ERROR"
    }
}

function Start-DriverCheck {
    Update-Status "Checking device drivers..."

    try {
        $drivers = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
        if ($drivers.Count -eq 0) {
            Update-Status "All device drivers are working properly" "SUCCESS"
        } else {
            Update-Status "Found $($drivers.Count) device(s) with driver issues" "WARN"
            foreach ($driver in $drivers) {
                Update-Status "Issue: $($driver.Name)" "WARN"
            }
        }
    } catch {
        Update-Status "Driver check failed: $($_.Exception.Message)" "ERROR"
    }
}

function Clear-DNSCache {
    Update-Status "Flushing DNS cache..."

    try {
        $process = Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Update-Status "DNS cache flushed successfully" "SUCCESS"
        } else {
            Update-Status "DNS flush completed with warnings" "WARN"
        }
    } catch {
        Update-Status "DNS flush failed: $($_.Exception.Message)" "ERROR"
    }
}

function Reset-NetworkStack {
    Update-Status "Resetting network stack..."

    try {
        $commands = @(
            @{ Cmd = "netsh"; Args = "winsock reset" },
            @{ Cmd = "netsh"; Args = "int ip reset" },
            @{ Cmd = "ipconfig"; Args = "/release" },
            @{ Cmd = "ipconfig"; Args = "/renew" }
        )

        foreach ($command in $commands) {
            $process = Start-Process -FilePath $command.Cmd -ArgumentList $command.Args -PassThru -Wait -WindowStyle Hidden
            if ($process.ExitCode -ne 0) {
                Update-Status "Warning: $($command.Cmd) $($command.Args) exited with code $($process.ExitCode)" "WARN"
            }
        }

        Update-Status "Network stack reset completed - restart required" "SUCCESS"
    } catch {
        Update-Status "Network reset failed: $($_.Exception.Message)" "ERROR"
    }
}

function Start-DiskCleanup {
    Update-Status "Starting Disk Cleanup utility..."

    try {
        Start-Process -FilePath "cleanmgr" -ArgumentList "/sagerun:1" -ErrorAction Stop
        Update-Status "Disk Cleanup utility started" "SUCCESS"
    } catch {
        Update-Status "Failed to start Disk Cleanup: $($_.Exception.Message)" "ERROR"
    }
}

function Start-Debloat {
    Update-Status "Starting Windows debloat process..."

    $bloatwareApps = @(
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.NetworkSpeedTest",
        "Microsoft.News",
        "Microsoft.Office.Lens",
        "Microsoft.Office.OneNote",
        "Microsoft.Office.Sway",
        "Microsoft.OneConnect",
        "Microsoft.People",
        "Microsoft.Print3D",
        "Microsoft.SkypeApp",
        "Microsoft.StorePurchaseApp",
        "Microsoft.Office.Todo.List",
        "Microsoft.Whiteboard",
        "Microsoft.WindowsAlarms",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )

    $removedCount = 0
    foreach ($app in $bloatwareApps) {
        try {
            $package = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
            if ($package) {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                Update-Status "Removed: $app" "SUCCESS"
                $removedCount++
            }
        } catch {
            Update-Status "Failed to remove: $app" "WARN"
        }
    }

    Update-Status "Debloat completed - removed $removedCount apps" "SUCCESS"
}

function Remove-VRChatRegistry {
    Update-Status "Removing VRChat registry entries..."

    $registryPaths = @(
        "HKCU:\Software\VRChat",
        "HKLM:\Software\VRChat",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\VRChat"
    )

    $removedCount = 0
    foreach ($regPath in $registryPaths) {
        try {
            if (Test-Path $regPath) {
                Remove-Item -Path $regPath -Recurse -Force -Confirm:$false
                Update-Status "Removed registry key: $regPath" "SUCCESS"
                $removedCount++
            }
        } catch {
            Update-Status "Failed to remove: $regPath" "ERROR"
        }
    }

    Update-Status "VRChat registry cleanup complete - removed $removedCount entries" "SUCCESS"
}

function Invoke-YureiMaintenance {
    Update-Status "Starting Yurei's maintenance routine..." "INFO"

    Clear-TempFiles
    Clear-BrowserCache
    Clear-DNSCache
    Reset-NetworkStack
    Clear-VRChatData
    Clear-RecycleBin
    Start-SFCScan
    Start-DriverCheck
    Start-DiskCleanup

    Update-Status "Yurei's maintenance completed successfully!" "SUCCESS"
}

function Invoke-MystMaintenance {
    Update-Status "Starting Myst's maintenance routine..." "INFO"

    Clear-TempFiles
    Clear-BrowserCache
    Clear-DNSCache
    Reset-NetworkStack
    Clear-VRChatData
    Clear-RecycleBin
    Start-SFCScan
    Start-DriverCheck
    Start-DiskCleanup

    Update-Status "Myst's maintenance completed successfully!" "SUCCESS"
}
