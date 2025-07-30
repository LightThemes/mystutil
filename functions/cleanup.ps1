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

function Clear-DNSCache {
    try {
        Clear-DnsClientCache
        Update-Status "DNS cache flushed successfully"
    }
    catch {
        Update-Status "Failed to flush DNS cache: $($_.Exception.Message)" "ERROR"
    }
}