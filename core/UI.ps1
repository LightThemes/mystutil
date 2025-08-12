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
