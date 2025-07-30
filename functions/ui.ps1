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
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#1E1E1E"/>
                                <Setter Property="BorderBrush" Value="#64B5F6"/>
                                <Setter Property="BorderThickness" Value="2"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#1E1E1E"/>
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
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1E1E1E"/>
                    <Setter Property="BorderBrush" Value="#64B5F6"/>
                    <Setter Property="BorderThickness" Value="2"/>
                </Trigger>
            </Style.Triggers>
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
                            <ScrollContentPresenter Grid.Column="0" Content="{TemplateBinding Content}"/>
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
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Vertical" VerticalAlignment="Center">
                        <TextBlock Text="MystUtil" FontSize="24" FontWeight="Bold"
                                Foreground="#64B5F6" FontFamily="Segoe UI"/>
                        <TextBlock Text="System Optimization by Myst" FontSize="11"
                                Foreground="White" FontFamily="Segoe UI"/>
                    </StackPanel>

                    <Border Grid.Column="1" Background="#1E1E1E" CornerRadius="8" BorderBrush="#3F3F46"
                            BorderThickness="1" Margin="20,0" Width="280" Height="38">
                        <TextBox Name="SearchBox" Background="Transparent" Foreground="#CCCCCC" BorderThickness="0"
                                VerticalContentAlignment="Center" FontSize="13" Text="Search tools..."
                                Padding="15,0" FontFamily="Segoe UI" CaretBrush="#1E1E1E"/>
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
                        <Border Name="OtherTabBorder" Background="#1E1E1E" CornerRadius="8"
                                BorderBrush="#64B5F6" BorderThickness="0" Style="{StaticResource TabStyle}"
                                Width="100" Height="38">
                            <TextBlock Text="Advanced" Foreground="White" FontSize="13" FontWeight="SemiBold"
                                    HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"/>
                        </Border>
                    </StackPanel>

                    <Border Grid.Column="3" Name="CloseButtonBorder" Background="#1E1E1E" CornerRadius="8"
                            BorderBrush="#64B5F6" BorderThickness="2"
                            Width="45" Height="38" Margin="20,0,0,0" Style="{StaticResource CloseButtonStyle}">
                    <TextBlock Text="X" Foreground="#64B5F6" FontSize="16" FontWeight="Bold"
                            HorizontalAlignment="Center" VerticalAlignment="Center"
                            FontFamily="Segoe UI" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display"/>
                    </Border>
                </Grid>
            </Border>

            <ScrollViewer Name="MainScrollViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto"
                        HorizontalScrollBarVisibility="Disabled"
                        Margin="30" Background="#1E1E1E" Style="{StaticResource ModernScrollViewerStyle}">
                <Border Background="#1E1E1E" Padding="30,5,30,15">
                    <Grid Name="MainContentGrid">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="25"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Name="LeftButtonContainer" Grid.Column="0" VerticalAlignment="Top"/>
                        <StackPanel Name="RightButtonContainer" Grid.Column="2" VerticalAlignment="Top"/>
                    </Grid>
                </Border>
            </ScrollViewer>

            <Border Grid.Row="2" Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="0,1,0,0">
                <Grid Margin="25,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Name="StatusText" Grid.Column="0" Text="Ready" Foreground="White"
                            VerticalAlignment="Center" FontSize="12" FontFamily="Segoe UI"/>

                    <TextBlock Grid.Column="1" Text="v2.1 | Running as Administrator" Foreground="#888888"
                            VerticalAlignment="Center" FontSize="10" FontFamily="Segoe UI"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
'@

#===========================================================================
# UI Functions
#===========================================================================

function New-CategoryHeader {
    [CmdletBinding()]
    param([string]$CategoryName)

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $CategoryName
    $header.FontSize = 15
    $header.FontWeight = "SemiBold"
    $header.FontFamily = "Segoe UI"
    $header.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $header.HorizontalAlignment = "Left"
    $header.Margin = "0,0,0,15"
    $header.Padding = "0,8,0,0"

    return $header
}

function New-Button {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Description,
        [string]$Action,
        [string]$Category,
        [string]$Icon = "[?]"
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Height = 50
    $button.Margin = "0,6,0,0"
    $button.Padding = "15,10"
    $button.HorizontalAlignment = "Stretch"
    $button.HorizontalContentAlignment = "Left"
    $button.ToolTip = $Description
    $button.Style = $script:sync.Window.Resources["ModernButtonStyle"]
    $button.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(40, 40, 45))
    $button.Foreground = [System.Windows.Media.Brushes]::White
    $button.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(70, 70, 70))
    $button.BorderThickness = "1"
    $button.Cursor = "Hand"

    $content = New-Object System.Windows.Controls.StackPanel
    $content.Orientation = "Horizontal"
    $content.VerticalAlignment = "Center"

    # Create icon container
    $iconContainer = New-Object System.Windows.Controls.Border
    $iconContainer.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 30, 30))
    $iconContainer.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $iconContainer.BorderThickness = "1"
    $iconContainer.CornerRadius = "4"
    $iconContainer.Width = 32
    $iconContainer.Height = 32
    $iconContainer.Margin = "5,0,12,0"
    $iconContainer.VerticalAlignment = "Center"

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $Icon.Trim('[', ']')
    $iconText.FontSize = 11
    $iconText.FontFamily = "Segoe UI"
    $iconText.FontWeight = "Bold"
    $iconText.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $iconText.HorizontalAlignment = "Center"
    $iconText.VerticalAlignment = "Center"
    $iconText.TextAlignment = "Center"

    $iconContainer.Child = $iconText

    $textContent = New-Object System.Windows.Controls.StackPanel
    $textContent.Orientation = "Vertical"

    $nameText = New-Object System.Windows.Controls.TextBlock
    $nameText.Text = $Name
    $nameText.FontSize = 13
    $nameText.FontFamily = "Segoe UI"
    $nameText.FontWeight = "SemiBold"
    $nameText.VerticalAlignment = "Center"

    $descText = New-Object System.Windows.Controls.TextBlock
    $descText.Text = $Description
    $descText.FontSize = 10
    $descText.FontFamily = "Segoe UI"
    $descText.Foreground = [System.Windows.Media.Brushes]::LightGray
    $descText.TextWrapping = "Wrap"
    $descText.Margin = "0,2,0,0"

    $textContent.Children.Add($nameText) | Out-Null
    $textContent.Children.Add($descText) | Out-Null

    $content.Children.Add($iconContainer) | Out-Null
    $content.Children.Add($textContent) | Out-Null
    $button.Content = $content

    # Store action and add click event
    $button.Tag = $Action
    $button.Add_Click({
            try {
                $actionName = $this.Tag
                Update-Status "Executing: $Name"
                & $actionName
            }
            catch {
                Update-Status "Error executing $Name`: $($_.Exception.Message)" "ERROR"
            }
        })

    return $button
}

function Show-Buttons {
    [CmdletBinding()]
    param([string]$Filter = "")

    $script:sync.LeftButtonContainer.Children.Clear()
    $script:sync.RightButtonContainer.Children.Clear()

    $buttons = $script:ButtonConfig | ForEach-Object {
        [PSCustomObject]@{
            Name        = $_.Name
            Description = $_.Description
            Action      = $_.Action
            Category    = if ($_.Category) { $_.Category } else { "Uncategorized" }
            Icon        = $_.Icon
        }
    }

    if ($script:sync.CurrentFilter -and $script:sync.CurrentFilter.Count -gt 0) {
        $buttons = $buttons | Where-Object { $_.Category -in $script:sync.CurrentFilter }
    }

    if ($Filter) {
        $buttons = $buttons | Where-Object {
            $_.Name -like "*$Filter*" -or $_.Description -like "*$Filter*" -or $_.Category -like "*$Filter*"
        }
    }

    if (!$buttons) {
        $noResults = New-Object System.Windows.Controls.TextBlock
        $noResults.Text = if ($Filter) { "No results found for: '$Filter'" } else { "No tools available in this category" }
        $noResults.FontSize = 16
        $noResults.Foreground = [System.Windows.Media.Brushes]::Gray
        $noResults.HorizontalAlignment = "Center"
        $noResults.Margin = "0,80,0,0"
        $noResults.FontFamily = "Segoe UI"
        $script:sync.LeftButtonContainer.Children.Add($noResults) | Out-Null
        return
    }

    # Group buttons by category and alternate containers
    $categories = $buttons | Group-Object Category | Sort-Object Name
    $leftColumn = $true

    foreach ($category in $categories) {
        $container = if ($leftColumn) { $script:sync.LeftButtonContainer } else { $script:sync.RightButtonContainer }

        # Create and add category header
        $catName = if ($category.Name -ne "") { $category.Name } else { "Uncategorized" }
        $header = New-CategoryHeader -CategoryName $catName

        # First category in each column gets no top margin for alignment
        if ($container.Children.Count -eq 0) {
            $header.Margin = "0,0,0,15"
        }
        else {
            $header.Margin = "0,25,0,15"
        }

        $container.Children.Add($header) | Out-Null

        # Add buttons for this category
        $category.Group | Sort-Object Name | ForEach-Object {
            $btn = New-Button -Name $_.Name -Description $_.Description -Action $_.Action -Category $_.Category -Icon $_.Icon
            $container.Children.Add($btn) | Out-Null
        }

        $leftColumn = !$leftColumn
    }
}

function Set-ActiveTab {
    [CmdletBinding()]
    param([string]$TabName)

    $mainTab = $script:sync.Window.FindName("MainTabBorder")
    $customTab = $script:sync.Window.FindName("CustomTabBorder")
    $otherTab = $script:sync.Window.FindName("OtherTabBorder")
    $activeColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))
    $inactiveColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 30, 30))
    $blueBorderColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(100, 181, 246))

    # Reset all tabs to inactive
    $mainTab.Background = $inactiveColor
    $mainTab.BorderBrush = $blueBorderColor
    $customTab.Background = $inactiveColor
    $customTab.BorderBrush = $blueBorderColor
    $otherTab.Background = $inactiveColor
    $otherTab.BorderBrush = $blueBorderColor

    if ($TabName -eq "Main") {
        $mainTab.Background = $activeColor
        $mainTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Cleanup", "Install", "System", "Games", "Extras")
    }
    elseif ($TabName -eq "Custom") {
        $customTab.Background = $activeColor
        $customTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Custom")
    }
    elseif ($TabName -eq "Advanced") {
        $otherTab.Background = $activeColor
        $otherTab.BorderBrush = $activeColor
        $script:sync.CurrentFilter = @("Advanced")
    }

    Show-Buttons
    $script:sync.Settings.LastTab = $TabName
    Save-Configuration
}

#===========================================================================
# Main Application Initialization
#===========================================================================

function Initialize-UI {
    Write-Log "Initializing UI interface..." -Level "INFO"

    try {
        $script:sync.Window = [Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]([xml]$xaml)))

        $script:sync.LeftButtonContainer = $script:sync.Window.FindName("LeftButtonContainer")
        $script:sync.RightButtonContainer = $script:sync.Window.FindName("RightButtonContainer")
        $script:sync.StatusText = $script:sync.Window.FindName("StatusText")
        $script:sync.SearchBox = $script:sync.Window.FindName("SearchBox")

        # Search functionality
        $searchTimer = New-Object System.Windows.Threading.DispatcherTimer
        $searchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
        $searchTimer.Add_Tick({
                $searchText = $script:sync.SearchBox.Text.Trim()
                if ($searchText -eq "Search tools..." -or [string]::IsNullOrWhiteSpace($searchText)) {
                    Show-Buttons
                }
                else {
                    Show-Buttons -Filter $searchText
                }
                $searchTimer.Stop()
            })

        $script:sync.SearchBox.Add_TextChanged({
                $searchTimer.Stop()
                $searchTimer.Start()
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
                    $this.Foreground = [System.Windows.Media.Brushes]::Gray
                }
            })

        # Window events
        $script:sync.Window.FindName("DragArea").Add_MouseLeftButtonDown({
                try {
                    $script:sync.Window.DragMove()
                }
                catch {
                    # Ignore drag errors
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

        $script:sync.Window.FindName("OtherTabBorder").Add_MouseLeftButtonDown({
                Set-ActiveTab -TabName "Advanced"
            })

        $script:sync.Window.Add_Closing({
                try {
                    $script:sync.Settings.WindowWidth = [int]$script:sync.Window.ActualWidth
                    $script:sync.Settings.WindowHeight = [int]$script:sync.Window.ActualHeight
                    Save-Configuration
                }
                catch {
                    # Ignore save errors on close
                }
            })

        Set-ActiveTab -TabName $script:sync.Settings.LastTab
        Update-Status "MystUtil ready - $($script:ButtonConfig.Count) tools available"

        Write-Log "UI initialization completed successfully" -Level "INFO"

        $script:sync.Window.ShowDialog() | Out-Null

    }
    catch {
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