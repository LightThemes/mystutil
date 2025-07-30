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