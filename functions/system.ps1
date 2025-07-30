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
        }
        catch {
            Update-Status "Failed: $($command.Desc)" "ERROR"
        }
    }

    Update-Status "Network reset complete - restart recommended for full effect"
}

function Start-SFCScan {
    try {
        Update-Status "Starting System File Checker scan (this may take several minutes)..." "INFO"
        Write-Log "SFC scan initiated" -Level "INFO"

        # Start SFC process in background
        $job = Start-Job -ScriptBlock {
            $process = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $env:TEMP\sfc_output.txt
            return @{
                ExitCode = $process.ExitCode
                Output   = if (Test-Path "$env:TEMP\sfc_output.txt") { Get-Content "$env:TEMP\sfc_output.txt" -Raw } else { "" }
            }
        }

        # Update status while job is running
        $elapsed = 0
        while ($job.State -eq "Running") {
            Start-Sleep -Seconds 10
            $elapsed += 10
            $minutes = [math]::Floor($elapsed / 60)
            $seconds = $elapsed % 60
            Update-Status "SFC scan in progress... (${minutes}m ${seconds}s elapsed)" "INFO"
        }

        # Get result and wait for completion
        $result = Receive-Job -Job $job -Wait
        Remove-Job -Job $job

        $exitCode = $result.ExitCode
        $totalMinutes = [math]::Floor($elapsed / 60)
        $totalSeconds = $elapsed % 60

        # Report results with completion time
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

        # Small delay to show completion message
        Start-Sleep -Seconds 2

    }
    catch {
        Update-Status "Failed to run SFC scan: $($_.Exception.Message)" "ERROR"
        Write-Log "SFC scan failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Start-DiskCleanup {
    try {
        Update-Status "Running automated disk cleanup..."

        # Run disk cleanup with all options enabled, no UI
        $process = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -PassThru -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Update-Status "Automated disk cleanup completed successfully"
        }
        else {
            Update-Status "Disk cleanup completed with exit code: $($process.ExitCode)" "WARN"
        }
    }
    catch {
        Update-Status "Failed to run automated disk cleanup: $($_.Exception.Message)" "ERROR"
    }
}