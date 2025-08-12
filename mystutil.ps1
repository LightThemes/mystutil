#Requires -Version 5.1

param (
    [switch]$DebugMode,
    [string]$Config,
    [switch]$Run,
    [switch]$NoSingleInstance
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

$script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$script:sync = [Hashtable]::Synchronized(@{
        LogPath      = Join-Path $env:TEMP "MystUtil.log"
        ConfigPath   = Join-Path $env:APPDATA "MystUtil"
        SettingsFile = Join-Path $env:APPDATA "MystUtil\settings.json"
    })

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch] -and $_.Value) {
            $arguments += "-$($_.Key)"
        } elseif ($_.Value) {
            $arguments += "-$($_.Key)", "'$($_.Value)'"
        }
    }

    $argumentString = $arguments -join ' '
    $script = "& '$PSCommandPath' $argumentString"
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    exit
}

if (!$NoSingleInstance) {
    Get-Process -Name "powershell*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID -and $_.MainWindowTitle -like "*MystUtil*" } |
    ForEach-Object { $_.CloseMainWindow() }
}

if ($Host.Name -eq "ConsoleHost") {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
}

$Host.UI.RawUI.WindowTitle = "MystUtil (Admin)"

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host " MystUtil - A System Optimization Tool" -ForegroundColor Cyan
Write-Host " https://github.com/LightThemes/mystutil" -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host ""

Write-Host "Loading core modules..." -ForegroundColor Yellow
$coreModules = @("Logging", "Initialize", "UI")
foreach ($module in $coreModules) {
    $modulePath = Join-Path $script:ScriptRoot "core\$module.ps1"
    if (Test-Path $modulePath) {
        . $modulePath
        Write-Host "Loaded core module: $module" -ForegroundColor Green
    } else {
        Write-Host "Core module not found: $modulePath" -ForegroundColor Red
        Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        Read-Host
        exit 1
    }
}

Write-Host "Loading functions..." -ForegroundColor Yellow
$functionsPath = Join-Path $script:ScriptRoot "functions\All-Functions.ps1"
if (Test-Path $functionsPath) {
    . $functionsPath
    Write-Host "Loaded all functions" -ForegroundColor Green
} else {
    Write-Host "Functions file not found: $functionsPath" -ForegroundColor Red
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

Write-Host "Loading button configuration..." -ForegroundColor Yellow
$buttonConfigPath = Join-Path $script:ScriptRoot "data\ButtonConfig.ps1"
if (Test-Path $buttonConfigPath) {
    . $buttonConfigPath
    Write-Host "Loaded button configuration" -ForegroundColor Green
} else {
    Write-Host "Button configuration not found: $buttonConfigPath" -ForegroundColor Red
    Write-Host "Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

Write-Log "MystUtil - Starting..." -Level "INFO"
Write-Log "Initializing configuration..." -Level "INFO"

try {
    Initialize-Configuration
    Initialize-UI
} catch {
    Write-Log "Application failed to start: $($_.Exception.Message)" -Level "ERROR"
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host " APPLICATION STARTUP FAILED" -ForegroundColor Red
    Write-Host ("=" * 70) -ForegroundColor Red
    Write-Host ""
    Write-Host " Error: " -ForegroundColor White -NoNewline
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host " Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
    exit 1
}
