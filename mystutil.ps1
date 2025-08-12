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

if ($Host.Name -eq "ConsoleHost") {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
}
$Host.UI.RawUI.WindowTitle = "MystUtil (Admin)"

$script:BlueColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
$script:GrayColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(180, 180, 180))
$script:DarkColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(42, 42, 47))

$script:SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(300)

function Invoke-Function {
    param([string]$FunctionName)

    try {
        & $FunctionName
    } catch {
        Update-Status "Function $FunctionName failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Function execution failed for {$FunctionName}: ${_}.Exception.Message" -Level "ERROR"
    }
}

function Install-Software {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$WingetId,
        [string]$FallbackUrl = "",
        [string]$FallbackArgs = ""
    )

    Update-Status "Preparing to install $Name..."

    try {
        $installed = winget list --id $WingetId --exact 2>$null
        if ($LASTEXITCODE -eq 0 -and $installed -match $WingetId) {
            Update-Status "$Name is already installed" "INFO"
            return
        }
    } catch {
        Write-Log "Could not check if $Name is installed: $($_.Exception.Message)" -Level "WARN"
    }

    try {
        Update-Status "Installing $Name via winget..."
        Write-Log "Installing $Name with winget ID: $WingetId" -Level "INFO"

        $null = winget install --id $WingetId --exact --silent --accept-package-agreements --accept-source-agreements 2>&1

        if ($LASTEXITCODE -eq 0) {
            Update-Status "$Name installed successfully via winget" "SUCCESS"
            Write-Log "$Name installation completed via winget" -Level "SUCCESS"
            return
        } else {
            Update-Status "Winget installation failed, trying fallback method..." "WARN"
            Write-Log "Winget failed for $Name (exit code: $LASTEXITCODE), trying fallback" -Level "WARN"
        }
    } catch {
        Update-Status "Winget installation failed: $($_.Exception.Message)" "WARN"
        Write-Log "Winget installation failed for ${Name}: $($_.Exception.Message)" -Level "WARN"
    }

    if ($FallbackUrl) {
        try {
            Update-Status "Downloading $Name from fallback URL..."
            $fileName = "$($Name -replace ' ', '_')-installer.exe"
            $installerPath = Join-Path $env:TEMP $fileName

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($FallbackUrl, $installerPath)
            $webClient.Dispose()

            Update-Status "Installing $Name via direct download..."
            $process = Start-Process -FilePath $installerPath -ArgumentList $FallbackArgs -PassThru -Wait -WindowStyle Hidden

            if ($process.ExitCode -eq 0) {
                Update-Status "$Name installed successfully via fallback" "SUCCESS"
            } else {
                Update-Status "$Name installation completed with exit code: $($process.ExitCode)" "WARN"
            }

            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        } catch {
            Update-Status "Failed to install $Name via fallback: $($_.Exception.Message)" "ERROR"
            Write-Log "Fallback installation failed for ${Name}: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Update-Status "No fallback method available for $Name" "ERROR"
    }
}

function Clear-TempFiles {
    Update-Status "Starting comprehensive temp cleanup..."

    $tempPaths = @(
        @{ Path = $env:TEMP; Name = "User Temp Files" },
        @{ Path = "C:\Windows\Temp"; Name = "Windows Temp Files" },
        @{ Path = "C:\Windows\Prefetch"; Name = "Prefetch Files" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Name = "Internet Cache" },
        @{ Path = "$env:LOCALAPPDATA\Temp"; Name = "Local App Temp" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "Web Cache" },
        @{ Path = "$env:APPDATA\Microsoft\Windows\Recent"; Name = "Recent Items" }
    )

    $totalFreed = 0
    foreach ($tempPath in $tempPaths) {
        if ($tempPath.Path -eq $env:TEMP) {
            $totalFreed += Remove-ItemsSafely -Path $tempPath.Path -Description $tempPath.Name -ExcludeFiles @("MystUtil.log")
        } else {
            $totalFreed += Remove-ItemsSafely -Path $tempPath.Path -Description $tempPath.Name
        }
    }

    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $totalFreed += Remove-ItemsSafely -Path "C:\Windows\SoftwareDistribution\Download" -Description "Windows Update Cache"
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    } catch {
        Update-Status "Could not clean Windows Update cache" "WARN"
    }

    Update-Status "Temp cleanup complete - ${totalFreed}MB freed (MystUtil.log preserved)" "SUCCESS"
}

function Clear-BrowserCache {
    Update-Status "Starting browser cache cleanup..."

    $browsers = @(
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache*" },
        @{ Name = "Edge"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache*" },
        @{ Name = "Firefox"; Path = "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache*" }
    )

    $totalFreed = 0
    foreach ($browser in $browsers) {
        $paths = Get-ChildItem -Path $browser.Path -Directory -ErrorAction SilentlyContinue
        foreach ($path in $paths) {
            $totalFreed += Remove-ItemsSafely -Path $path.FullName -Description "$($browser.Name) Cache"
        }
    }

    Update-Status "Browser cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Clear-RecycleBin {
    Update-Status "Emptying Recycle Bin..."

    try {
        $Shell = New-Object -ComObject Shell.Application
        $RecycleBin = $Shell.Namespace(0xA)
        $RecycleBin.Self.InvokeVerb("Empty Recycle Bin")
        Update-Status "Recycle Bin emptied successfully" "SUCCESS"
    } catch {
        Update-Status "Failed to empty Recycle Bin: $($_.Exception.Message)" "ERROR"
    }
}

function Clear-SpotifyCache {
    Update-Status "Clearing Spotify cache and data..."

    $spotifyPaths = @(
        "$env:APPDATA\Spotify\Data",
        "$env:APPDATA\Spotify\Browser\Cache",
        "$env:APPDATA\Spotify\Storage"
    )

    $totalFreed = 0
    foreach ($path in $spotifyPaths) {
        $totalFreed += Remove-ItemsSafely -Path $path -Description "Spotify Cache"
    }

    Update-Status "Spotify cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Clear-SteamCache {
    Update-Status "Clearing Steam cache and temporary files..."

    $steamPaths = @(
        "$env:PROGRAMFILES(X86)\Steam\appcache",
        "$env:PROGRAMFILES(X86)\Steam\logs",
        "$env:PROGRAMFILES(X86)\Steam\dumps"
    )

    $totalFreed = 0
    foreach ($path in $steamPaths) {
        $totalFreed += Remove-ItemsSafely -Path $path -Description "Steam Cache"
    }

    Update-Status "Steam cache cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Clear-VRChatData {
    Update-Status "Clearing VRChat cache and temporary data..."

    $vrchatPaths = @(
        "$env:APPDATA\..\LocalLow\VRChat\VRChat\Cache-WindowsPlayer",
        "$env:APPDATA\..\LocalLow\VRChat\VRChat\Logs",
        "$env:TEMP\VRChat"
    )

    $totalFreed = 0
    foreach ($path in $vrchatPaths) {
        $totalFreed += Remove-ItemsSafely -Path $path -Description "VRChat Data"
    }

    Update-Status "VRChat cleanup complete - ${totalFreed}MB freed" "SUCCESS"
}

function Install-7Zip {
    Install-Software -Name "7-Zip" -WingetId "7zip.7zip" -FallbackUrl "https://www.7-zip.org/a/7z2301-x64.exe" -FallbackArgs "/S"
}

function Install-VSCode {
    Install-Software -Name "VS Code" -WingetId "Microsoft.VisualStudioCode" -FallbackUrl "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" -FallbackArgs "/VERYSILENT /NORESTART"
}

function Install-Chrome {
    Install-Software -Name "Google Chrome" -WingetId "Google.Chrome" -FallbackUrl "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi" -FallbackArgs "/quiet /norestart"
}

function Install-WinRAR {
    Install-Software -Name "WinRAR" -WingetId "RARLab.WinRAR" -FallbackUrl "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-623.exe" -FallbackArgs "/S"
}

function Install-Spotify {
    Install-Software -Name "Spotify" -WingetId "Spotify.Spotify" -FallbackUrl "https://download.scdn.co/SpotifySetup.exe" -FallbackArgs "/silent"
}

function Install-Steam {
    Install-Software -Name "Steam" -WingetId "Valve.Steam" -FallbackUrl "https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe" -FallbackArgs "/S"
}

function Start-SFCScan {
    Update-Status "Running System File Checker scan..."

    try {
        $process = Start-Process -FilePath "sfc" -ArgumentList "/scannow" -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Update-Status "SFC scan completed successfully" "SUCCESS"
        } else {
            Update-Status "SFC scan completed with issues (exit code: $($process.ExitCode))" "WARN"
        }
    } catch {
        Update-Status "SFC scan failed: $($_.Exception.Message)" "ERROR"
    }
}

function Start-DISMScan {
    Update-Status "Running DISM health scan..."

    try {
        $process = Start-Process -FilePath "dism" -ArgumentList "/online /cleanup-image /scanhealth" -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Update-Status "DISM scan completed successfully" "SUCCESS"
        } else {
            Update-Status "DISM scan found issues - running repair..." "WARN"
            $repairProcess = Start-Process -FilePath "dism" -ArgumentList "/online /cleanup-image /restorehealth" -PassThru -Wait -WindowStyle Hidden
            if ($repairProcess.ExitCode -eq 0) {
                Update-Status "DISM repair completed successfully" "SUCCESS"
            } else {
                Update-Status "DISM repair completed with issues (exit code: $($repairProcess.ExitCode))" "WARN"
            }
        }
    } catch {
        Update-Status "DISM scan failed: $($_.Exception.Message)" "ERROR"
    }
}

function Start-DriverCheck {
    Update-Status "Checking device drivers..."

    try {
        $drivers = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
        if ($drivers.Count -eq 0) {
            Update-Status "All device drivers are working properly" "SUCCESS"
        } else {
            Update-Status "Found $($drivers.Count) device(s) with driver issues" "WARN"
            foreach ($driver in $drivers) {
                Update-Status "Issue: $($driver.Name)" "WARN"
            }
        }
    } catch {
        Update-Status "Driver check failed: $($_.Exception.Message)" "ERROR"
    }
}

function Clear-DNSCache {
    Update-Status "Flushing DNS cache..."

    try {
        $process = Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -PassThru -Wait -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            Update-Status "DNS cache flushed successfully" "SUCCESS"
        } else {
            Update-Status "DNS flush completed with warnings" "WARN"
        }
    } catch {
        Update-Status "DNS flush failed: $($_.Exception.Message)" "ERROR"
    }
}

function Reset-NetworkStack {
    Update-Status "Resetting network stack..."

    try {
        $commands = @(
            @{ Cmd = "netsh"; Args = "winsock reset" },
            @{ Cmd = "netsh"; Args = "int ip reset" },
            @{ Cmd = "ipconfig"; Args = "/release" },
            @{ Cmd = "ipconfig"; Args = "/renew" }
        )

        foreach ($command in $commands) {
            $process = Start-Process -FilePath $command.Cmd -ArgumentList $command.Args -PassThru -Wait -WindowStyle Hidden
            if ($process.ExitCode -ne 0) {
                Update-Status "Warning: $($command.Cmd) $($command.Args) exited with code $($process.ExitCode)" "WARN"
            }
        }

        Update-Status "Network stack reset completed - restart required" "SUCCESS"
    } catch {
        Update-Status "Network reset failed: $($_.Exception.Message)" "ERROR"
    }
}

function Start-DiskCleanup {
    Update-Status "Starting Disk Cleanup utility..."

    try {
        Start-Process -FilePath "cleanmgr" -ArgumentList "/sagerun:1" -ErrorAction Stop
        Update-Status "Disk Cleanup utility started" "SUCCESS"
    } catch {
        Update-Status "Failed to start Disk Cleanup: $($_.Exception.Message)" "ERROR"
    }
}

function Start-Debloat {
    Update-Status "Starting Windows debloat process..."

    $bloatwareApps = @(
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.NetworkSpeedTest",
        "Microsoft.News",
        "Microsoft.Office.Lens",
        "Microsoft.Office.OneNote",
        "Microsoft.Office.Sway",
        "Microsoft.OneConnect",
        "Microsoft.People",
        "Microsoft.Print3D",
        "Microsoft.SkypeApp",
        "Microsoft.StorePurchaseApp",
        "Microsoft.Office.Todo.List",
        "Microsoft.Whiteboard",
        "Microsoft.WindowsAlarms",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo"
    )

    $removedCount = 0
    foreach ($app in $bloatwareApps) {
        try {
            $package = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
            if ($package) {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                Update-Status "Removed: $app" "SUCCESS"
                $removedCount++
            }
        } catch {
            Update-Status "Failed to remove: $app" "WARN"
        }
    }

    Update-Status "Debloat completed - removed $removedCount apps" "SUCCESS"
}

function Remove-VRChatRegistry {
    Update-Status "Removing VRChat registry entries..."

    $registryPaths = @(
        "HKCU:\Software\VRChat",
        "HKLM:\Software\VRChat",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\VRChat"
    )

    $removedCount = 0
    foreach ($regPath in $registryPaths) {
        try {
            if (Test-Path $regPath) {
                Remove-Item -Path $regPath -Recurse -Force -Confirm:$false
                Update-Status "Removed registry key: $regPath" "SUCCESS"
                $removedCount++
            }
        } catch {
            Update-Status "Failed to remove: $regPath" "ERROR"
        }
    }

    Update-Status "VRChat registry cleanup complete - removed $removedCount entries" "SUCCESS"
}

function Invoke-YureiMaintenance {
    Update-Status "Starting Yurei's maintenance routine..." "INFO"

    Clear-TempFiles
    Clear-BrowserCache
    Clear-DNSCache
    Reset-NetworkStack
    Clear-VRChatData
    Clear-RecycleBin
    Start-SFCScan
    Start-DriverCheck
    Start-DiskCleanup

    Update-Status "Yurei's maintenance completed successfully!" "SUCCESS"
}

function Invoke-MystMaintenance {
    Update-Status "Starting Myst's maintenance routine..." "INFO"

    Clear-TempFiles
    Clear-BrowserCache
    Clear-DNSCache
    Reset-NetworkStack
    Clear-VRChatData
    Clear-RecycleBin
    Start-SFCScan
    Start-DriverCheck
    Start-DiskCleanup

    Update-Status "Myst's maintenance completed successfully!" "SUCCESS"
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MystUtil" Height="700" Width="900"
        WindowStartupLocation="CenterScreen" Background="#1E1E1E" MinHeight="600" MinWidth="800"
        WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResize">

    <Window.Resources>
        <Style x:Key="ModernButtonStyle" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                                            Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#4A4A52"/>
                                <Setter Property="BorderBrush" Value="#64B5F6"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#52525A"/>
                                <Setter Property="BorderBrush" Value="#64B5F6"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="TabStyle" TargetType="Border">
            <Setter Property="Cursor" Value="Hand"/>
        </Style>

        <Style x:Key="ModernScrollViewerStyle" TargetType="ScrollViewer">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollViewer">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <ScrollContentPresenter Grid.Column="0"/>
                            <ScrollBar Grid.Column="1" Name="PART_VerticalScrollBar"
                                    Value="{TemplateBinding VerticalOffset}"
                                    Maximum="{TemplateBinding ScrollableHeight}"
                                    ViewportSize="{TemplateBinding ViewportHeight}"
                                    Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}"
                                    Width="12" Background="#1E1E1E" BorderThickness="0"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6">
                            <Track Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb Background="#3F3F46" BorderThickness="0" Margin="2">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="6"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CloseButtonStyle" TargetType="Border">
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1E1E1E"/>
                    <Setter Property="BorderBrush" Value="#64B5F6"/>
                    <Setter Property="BorderThickness" Value="2"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Border BorderBrush="#3F3F46" BorderThickness="2" Background="#1E1E1E">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="70"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="40"/>
            </Grid.RowDefinitions>

            <Border Name="DragArea" Grid.Row="0" Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="0,0,0,1">
                <Grid Margin="25,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                        <TextBlock Text="MystUtil" FontSize="24" FontWeight="Bold"
                                Foreground="#64B5F6" FontFamily="Segoe UI"/>
                        <TextBlock Text="A System Optimization Tool" FontSize="11" FontWeight="Bold"
                                Foreground="White" FontFamily="Segoe UI"/>
                    </StackPanel>

                    <Border Grid.Column="1" Background="#1E1E1E" CornerRadius="8" BorderBrush="#3F3F46"
                            BorderThickness="1" Margin="20,0" Width="280" Height="38">
                        <TextBox Name="SearchBox" Background="Transparent" Foreground="#64B5F6" BorderThickness="0"
                                VerticalContentAlignment="Center" FontSize="13" Text="Search tools..."
                                Padding="15,0" FontFamily="Segoe UI" CaretBrush="#64B5F6"/>
                    </Border>

                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="15,0">
                        <Border Name="MainTabBorder" Background="#64B5F6" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="0" Style="{StaticResource TabStyle}"
                                Margin="0,0,5,0" Width="100" Height="38">
                            <TextBlock Text="Main Tools" Foreground="White" FontSize="13" FontWeight="SemiBold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"/>
                        </Border>
                        <Border Name="CustomTabBorder" Background="#1E1E1E" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="0" Style="{StaticResource TabStyle}"
                                Margin="0,0,5,0" Width="75" Height="38">
                            <TextBlock Text="Custom" Foreground="White" FontSize="12" FontWeight="SemiBold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"/>
                        </Border>

                        <Border Name="CloseButtonBorder" Background="#1E1E1E" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="2"
                                Width="45" Height="38" Margin="20,0,0,0" Style="{StaticResource CloseButtonStyle}">
                            <TextBlock Text="✕" Foreground="#64B5F6" FontSize="16" FontWeight="Bold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center"
                                    FontFamily="Segoe UI" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display"/>
                        </Border>
                    </StackPanel>
                </Grid>
            </Border>

            <ScrollViewer Name="MainScrollViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto"
                        HorizontalScrollBarVisibility="Disabled"
                        Margin="40" Background="#1E1E1E" Style="{StaticResource ModernScrollViewerStyle}">
                <Border Background="#1E1E1E" Padding="40,20,40,30">
                    <Grid Name="MainContentGrid">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Name="LeftButtonContainer" VerticalAlignment="Top"/>
                    </Grid>
                </Border>
            </ScrollViewer>

            <Border Grid.Row="2" Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="0,1,0,0">
                <Grid Margin="25,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Name="StatusText" Grid.Column="0" Text="" Foreground="#64B5F6"
                            VerticalAlignment="Center" FontSize="12" FontFamily="Segoe UI" FontWeight="Bold"/>

                    <TextBlock Grid.Column="1" Text="version: 4.3.2" Foreground="#64B5F6"
                            VerticalAlignment="Center" FontSize="12" FontFamily="Segoe UI" FontWeight="Bold"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
'@

function New-CategoryHeader {
    [CmdletBinding()]
    param([string]$CategoryName)

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $CategoryName
    $header.FontSize = 16
    $header.FontWeight = "Bold"
    $header.FontFamily = "Segoe UI"
    $header.Foreground = $script:BlueColor
    $header.HorizontalAlignment = "Left"
    $header.Margin = "0,25,0,20"
    $header.Padding = "0,12,0,8"

    return $header
}

function New-Button {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Description,
        [string]$Action,
        [string]$Icon = "[?]"
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Height = 65
    $button.Margin = "0,8,0,0"
    $button.Padding = "20,12"
    $button.HorizontalAlignment = "Stretch"
    $button.HorizontalContentAlignment = "Left"
    $button.ToolTip = $Description
    $button.Style = $script:sync.Window.Resources["ModernButtonStyle"]
    $button.Background = $script:DarkColor
    $button.Foreground = [System.Windows.Media.Brushes]::White
    $button.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(75, 75, 75))
    $button.BorderThickness = "1"
    $button.Cursor = "Hand"

    $content = New-Object System.Windows.Controls.StackPanel
    $content.Orientation = "Horizontal"
    $content.VerticalAlignment = "Center"

    $iconContainer = New-Object System.Windows.Controls.Border
    $iconContainer.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(28, 28, 30))
    $iconContainer.BorderBrush = $script:BlueColor
    $iconContainer.BorderThickness = "1.5"
    $iconContainer.CornerRadius = "6"
    $iconContainer.Width = 38
    $iconContainer.Height = 38
    $iconContainer.Margin = "8,0,18,0"
    $iconContainer.VerticalAlignment = "Center"

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $Icon.Trim('[', ']')
    $iconText.FontSize = 12
    $iconText.FontFamily = "Segoe UI"
    $iconText.FontWeight = "Bold"
    $iconText.Foreground = $script:BlueColor
    $iconText.HorizontalAlignment = "Center"
    $iconText.VerticalAlignment = "Center"
    $iconText.TextAlignment = "Center"

    $iconContainer.Child = $iconText

    $textContent = New-Object System.Windows.Controls.StackPanel
    $textContent.Orientation = "Vertical"
    $textContent.VerticalAlignment = "Center"

    $nameText = New-Object System.Windows.Controls.TextBlock
    $nameText.Text = $Name
    $nameText.FontSize = 14
    $nameText.FontFamily = "Segoe UI"
    $nameText.FontWeight = "SemiBold"
    $nameText.VerticalAlignment = "Center"
    $nameText.Margin = "0,0,0,4"

    $descText = New-Object System.Windows.Controls.TextBlock
    $descText.Text = $Description
    $descText.FontSize = 11
    $descText.FontFamily = "Segoe UI"
    $descText.Foreground = $script:GrayColor
    $descText.TextWrapping = "Wrap"
    $descText.LineHeight = 16

    $textContent.Children.Add($nameText) | Out-Null
    $textContent.Children.Add($descText) | Out-Null

    $content.Children.Add($iconContainer) | Out-Null
    $content.Children.Add($textContent) | Out-Null
    $button.Content = $content

    $button.Tag = @{ Action = $Action }
    $button.Add_Click({
            $buttonConfig = $this.Tag
            Invoke-Function -FunctionName $buttonConfig.Action
        })

    return $button
}

function Show-Buttons {
    [CmdletBinding()]
    param([string]$Filter = "")

    $script:sync.LeftButtonContainer.Children.Clear()

    $buttons = $script:ButtonConfig | Where-Object {
        ($script:sync.CurrentFilter -contains $_.Category) -and
        ([string]::IsNullOrWhiteSpace($Filter) -or $Filter -eq "Search tools..." -or
        $_.Name -eq $Filter -or $_.Description -eq $Filter -or
        $_.Name -like "*$Filter*" -or $_.Description -like "*$Filter*"
    ) }

    if ($buttons.Count -eq 0) {
        $noButtonsText = New-Object System.Windows.Controls.TextBlock
        $noButtonsText.Text = if ($Filter -and $Filter -ne "Search tools...") { "No tools found matching '$Filter'" } else { "No tools available in this category" }
        $noButtonsText.FontSize = 16
        $noButtonsText.Foreground = [System.Windows.Media.Brushes]::Gray
        $noButtonsText.HorizontalAlignment = "Center"
        $noButtonsText.VerticalAlignment = "Center"
        $noButtonsText.Margin = "20"

        $script:sync.LeftButtonContainer.Children.Add($noButtonsText) | Out-Null
        return
    }

    $groupedButtons = @{}
    $categoryOrder = @()

    foreach ($button in $buttons) {
        if (-not $groupedButtons.ContainsKey($button.Category)) {
            $groupedButtons[$button.Category] = @()
            $categoryOrder += $button.Category
        }
        $groupedButtons[$button.Category] += $button
    }

    $categoryPriority = @{
        "Cleanup" = 1
        "Install" = 2
        "System"  = 3
        "Games"   = 4
        "Custom"  = 5
    }

    $categoryOrder = $categoryOrder | Sort-Object {
        if ($categoryPriority.ContainsKey($_)) {
            $categoryPriority[$_]
        } else {
            999
        }
    }

    foreach ($category in $categoryOrder) {
        $categoryButtons = $groupedButtons[$category]
        $categoryButtons = $categoryButtons | Sort-Object Name
        $header = New-CategoryHeader -CategoryName $category
        $script:sync.LeftButtonContainer.Children.Add($header) | Out-Null
        foreach ($config in $categoryButtons) {
            $button = New-Button -Name $config.Name -Description $config.Description -Action $config.Action -Icon $config.Icon
            $script:sync.LeftButtonContainer.Children.Add($button) | Out-Null
        }
    }
}

function Set-ActiveTab {
    [CmdletBinding()]
    param([string]$TabName)

    $mainTab = $script:sync.Window.FindName("MainTabBorder")
    $customTab = $script:sync.Window.FindName("CustomTabBorder")
    $activeColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $inactiveColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 30, 30))
    $blueBorderColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))

    $mainTab.Background = $inactiveColor
    $mainTab.BorderBrush = $blueBorderColor
    $customTab.Background = $inactiveColor
    $customTab.BorderBrush = $blueBorderColor

    if ($TabName -eq "Main") {
        $mainTab.Background = $activeColor
        $mainTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Cleanup", "Install", "System", "Games")
    } elseif ($TabName -eq "Custom") {
        $customTab.Background = $activeColor
        $customTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Custom")
    }

    Show-Buttons
    $script:sync.Settings.LastTab = $TabName
    Save-Configuration
}

function Initialize-UI {
    Write-Log "Initializing UI interface..." -Level "INFO"

    try {
        $script:sync.Window = [Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]([xml]$xaml)))

        $script:sync.LeftButtonContainer = $script:sync.Window.FindName("LeftButtonContainer")
        $script:sync.StatusText = $script:sync.Window.FindName("StatusText")
        $script:sync.SearchBox = $script:sync.Window.FindName("SearchBox")

        $script:SearchTimer.Add_Tick({
                $searchText = $script:sync.SearchBox.Text.Trim()
                if ($searchText -eq "Search tools..." -or [string]::IsNullOrWhiteSpace($searchText)) {
                    Show-Buttons
                } else {
                    Show-Buttons -Filter $searchText
                }
                $script:SearchTimer.Stop()
            })

        $script:sync.SearchBox.Add_TextChanged({
                $script:SearchTimer.Stop()
                $script:SearchTimer.Start()
            })

        $script:sync.SearchBox.Add_KeyDown({
                if ($_.Key -eq "Return") {
                    $searchText = $script:sync.SearchBox.Text.Trim()
                    if ($searchText -eq "Search tools..." -or [string]::IsNullOrWhiteSpace($searchText)) {
                        Show-Buttons
                    } else {
                        Show-Buttons -Filter $searchText
                    }
                    $_.Handled = $true
                }
            })

        $script:sync.SearchBox.Add_GotFocus({
                if ($this.Text -eq "Search tools...") {
                    $this.Text = ""
                    $this.Foreground = [System.Windows.Media.Brushes]::White
                }
            })

        $script:sync.SearchBox.Add_LostFocus({
                if ([string]::IsNullOrWhiteSpace($this.Text)) {
                    $this.Text = "Search tools..."
                    $this.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(100, 181, 246))
                }
            })

        $script:sync.Window.FindName("DragArea").Add_MouseLeftButtonDown({
                try {
                    $script:sync.Window.DragMove()
                } catch {
                    Write-Log "Window drag failed: $($_.Exception.Message)" -Level "DEBUG"
                }
            })

        $script:sync.Window.FindName("CloseButtonBorder").Add_MouseLeftButtonDown({
                $script:sync.Window.Close()
            })

        $script:sync.Window.FindName("MainTabBorder").Add_MouseLeftButtonDown({
                Set-ActiveTab -TabName "Main"
            })

        $script:sync.Window.FindName("CustomTabBorder").Add_MouseLeftButtonDown({
                Set-ActiveTab -TabName "Custom"
            })

        $script:sync.Window.Add_Closing({
                try {
                    $script:sync.Settings.WindowWidth = [int]$script:sync.Window.ActualWidth
                    $script:sync.Settings.WindowHeight = [int]$script:sync.Window.ActualHeight
                    Save-Configuration
                } catch { }
            })

        Set-ActiveTab -TabName $script:sync.Settings.LastTab
        Update-Status "MystUtil ready - $($script:ButtonCount) tools available"

        Write-Log "UI initialization completed successfully" -Level "INFO"

        $script:sync.Window.ShowDialog() | Out-Null

    } catch {
        Write-Log "Failed to initialize UI: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            "Failed to initialize the application interface.`n`nError: $($_.Exception.Message)",
            "Initialization Error",
            "OK",
            "Error"
        )
        throw
    }
}

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
                    $script:sync.StatusText.Foreground = $script:BlueColor
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

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Blue
Write-Host " MystUtil - A System Optimization Tool" -ForegroundColor Cyan
Write-Host " https://github.com/LightThemes/mystutil" -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor Blue

try {
    Initialize-Configuration
    Initialize-UI
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
