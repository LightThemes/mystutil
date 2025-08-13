function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        [System.IO.File]::AppendAllText($script:sync.LogPath, "$logEntry`n")
    } catch {
        if ($Level -eq "ERROR") {
            Write-Host "Logging failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($DebugMode -and $Level -eq "DEBUG") {
        Write-Host "[$timestamp] DEBUG: $Message" -ForegroundColor Cyan
    }
}

function Update-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"

    if ($script:sync.StatusText) {
        try {
            $script:sync.StatusText.Dispatcher.BeginInvoke([Action] {
                    $script:sync.StatusText.Text = $Message

                    $script:sync.StatusText.Foreground = switch ($Level) {
                        "SUCCESS" { [System.Windows.Media.Brushes]::LimeGreen }
                        "ERROR" { [System.Windows.Media.Brushes]::Red }
                        "WARN" { [System.Windows.Media.Brushes]::Orange }
                        default { [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246)) }
                    }
                }) | Out-Null
        } catch { }
    }

    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
    Write-Log $Message -Level $Level
}
