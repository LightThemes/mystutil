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
    }
    catch {
        # Silently fail if logging fails
    }

    if ($DebugMode -and $Level -eq "DEBUG") {
        Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
        Write-Host "DEBUG: " -ForegroundColor Magenta -NoNewline
        Write-Host $Message -ForegroundColor Gray
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
                }) | Out-Null
        }
        catch {
            # Silently fail if UI update fails
        }
    }

    $prefix = "[$timestamp]"
    $separator = " >> "

    switch ($Level) {
        "INFO" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host $Message -ForegroundColor Cyan
        }
        "SUCCESS" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host "SUCCESS: " -ForegroundColor Green -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "WARN" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host "WARNING: " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor White
        }
        "ERROR" {
            Write-Host $prefix -ForegroundColor DarkCyan -NoNewline
            Write-Host $separator -ForegroundColor Blue -NoNewline
            Write-Host "ERROR: " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor White
        }
    }

    Write-Log $Message -Level $Level

    try {
        [System.Windows.Forms.Application]::DoEvents()
    }
    catch {
        # Silently fail if DoEvents fails
    }
}