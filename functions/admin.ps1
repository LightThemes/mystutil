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