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