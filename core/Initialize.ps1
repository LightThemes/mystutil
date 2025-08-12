$script:BlueColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
$script:GrayColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(180, 180, 180))
$script:DarkColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(42, 42, 47))

$script:SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(300)

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
