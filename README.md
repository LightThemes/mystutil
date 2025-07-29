# MystUtil

Windows system optimization tool with a modern dark UI.

## Quick Start

**Run directly (recommended):**

```powershell
irm https://raw.githubusercontent.com/LightThemes/mystutil/main/mystutil.ps1 | iex
```

Or, **download and run manually:**

1. [Download mystutil.ps1](https://github.com/LightThemes/mystutil/raw/main/mystutil.ps1)
2. Right-click the file, choose **Run with PowerShell** (or open a PowerShell window and run `.\mystutil.ps1`)

> **Note:** You may need to right-click and select **Run as administrator** for full functionality.

---

## Usage

- On launch, MystUtil will open a modern window with categorized tools.
- Click any tool button to run its maintenance or optimization task.
- Status and results will be shown in the window and the PowerShell console.
- Some tools may prompt for confirmation or show progress in the status bar.
- Logs are saved to `%TEMP%\MystUtil.log` for troubleshooting.

### Common Tasks

- **Cleanup**: Remove temp files, browser cache, recycle bin, VRChat data
- **Install**: Download and install popular utilities (7-Zip, VS Code, Chrome, WinRAR)
- **System**: Run SFC scan, reset network, flush DNS
- **Advanced**: Disk cleanup, open registry editor, launch admin terminals
- **Custom**: Access your own tools in the Personal section

---

## Requirements

- Windows 10/11
- Admin privileges (auto-requested)

## ⚠️ Disclaimer

**Use at your own risk.** This software is provided "as is" without warranty. The author is not responsible for any damage or data loss. Always backup important data before use.
