function Install-7Zip {
    Install-Software -Name "7-Zip" -Url "https://www.7-zip.org/a/7z2301-x64.exe" -Arguments "/S"
}

function Install-VSCode {
    Install-Software -Name "VS Code" -Url "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" -Arguments "/VERYSILENT /NORESTART" -FileName "VSCode.exe"
}

function Install-Chrome {
    Install-Software -Name "Chrome" -Url "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi" -Arguments "/quiet /norestart" -FileName "Chrome.msi"
}

function Install-WinRAR {
    Install-Software -Name "WinRAR" -Url "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-623.exe" -Arguments "/S"
}