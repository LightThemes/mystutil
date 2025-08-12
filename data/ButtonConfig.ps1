$script:ButtonConfig = @(
    @{ Name = "Empty Recycle Bin"; Description = "Permanently deletes all items in Recycle Bin"; Action = "Clear-RecycleBin"; Category = "Cleanup"; Icon = "[BIN]" },
    @{ Name = "Clear Temp Files"; Description = "Comprehensive cleanup of temporary files and caches"; Action = "Clear-TempFiles"; Category = "Cleanup"; Icon = "[DEL]" },
    @{ Name = "Clear Browser Cache"; Description = "Removes cache files from all major browsers"; Action = "Clear-BrowserCache"; Category = "Cleanup"; Icon = "[WEB]" },
    @{ Name = "Clear Spotify Cache"; Description = "Clears Spotify cache and temporary data"; Action = "Clear-SpotifyCache"; Category = "Cleanup"; Icon = "[SPT]" },
    @{ Name = "Clear Steam Cache"; Description = "Clears Steam cache, logs, and temporary files"; Action = "Clear-SteamCache"; Category = "Cleanup"; Icon = "[STM]" },
    @{ Name = "Clear VRChat Data"; Description = "Clears VRChat cache, logs, and temporary data"; Action = "Clear-VRChatData"; Category = "Cleanup"; Icon = "[VRC]" },

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

    @{ Name = "Remove VRChat Registry"; Description = "Removes VRChat registry keys and startup entries"; Action = "Remove-VRChatRegistry"; Category = "Games"; Icon = "[VRC]" },

    @{ Name = "Yurei"; Description = "For Yurei"; Action = "Invoke-YureiMaintenance"; Category = "Custom"; Icon = "[TEST]" },
    @{ Name = "Myst"; Description = "For Myst"; Action = "Invoke-MystMaintenance"; Category = "Custom"; Icon = "[TEST]" }
)

$script:ButtonCount = $script:ButtonConfig.Count
