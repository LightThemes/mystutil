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