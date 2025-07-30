function Invoke-Yurei {
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

function Invoke-Myst {
    try {
        Update-Status "Myst's custom maintenance is starting..." "INFO"
        Write-Log "Starting Myst's personalized system cleanup routine." -Level "INFO"

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