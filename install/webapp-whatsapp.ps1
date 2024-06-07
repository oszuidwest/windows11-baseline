# Define the shortcut details
$shortcutName = "WhatsApp"
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$whatsappUrl = "https://web.whatsapp.com"
#TODO: $iconPath = "C:\Path\To\Your\Icon.ico"
	
# Arguments for Edge to open WhatsApp Web in app mode, in private window, and specified size
$browserArguments = "--app=$whatsappUrl --inprivate --window-size=640,360"

# Path to the Default User profile's Desktop directory
$defaultDesktopPath = "C:\Users\Default\Desktop"

# Check if Desktop directory exists
if (Test-Path -Path $defaultDesktopPath) {
    $shortcutPath = "$defaultDesktopPath\$shortcutName.lnk"

    # Create WScript.Shell COM object
    $wshShell = New-Object -ComObject WScript.Shell

    # Create a new shortcut
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $edgePath
    $shortcut.Arguments = $browserArguments
    $shortcut.Description = "Open WhatsApp"
    $shortcut.WorkingDirectory = Split-Path $edgePath
    
    # TODO: Add an icon to the shortcut
    # $shortcut.IconLocation = $iconPath

    $shortcut.Save()

    Write-Output "Shortcut for WhatsApp created"
}
else {
    Write-Output "No Desktop directory found in the Default User profile"
}
