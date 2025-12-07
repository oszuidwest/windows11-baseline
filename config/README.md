# Configuration Files

This directory contains configuration files for deployment tools.

## BGInfo Configuration

### `bginfo.bgi`

BGInfo configuration file for dedicated systems. This file defines which system information is displayed on the desktop wallpaper.

**To create or modify the BGInfo configuration:**

1. Run BGInfo64.exe on a Windows machine (download from https://live.sysinternals.com/bginfo64.exe)
2. Configure the fields you want to display:
   - Host Name
   - IP Address
   - MAC Address
   - Default Gateway
   - Boot Time
   - OS Version
   - CPU
   - Memory
   - Free Space
3. Adjust position (recommended: top-right or bottom-right)
4. Set background to "Copy existing wallpaper" to overlay on black background
5. File → Save As → `bginfo.bgi`
6. Copy the file to this directory

**Recommended settings:**
- Position: Right side of screen
- Font: Lucida Console, 9pt
- Background: Copy user's current wallpaper

**If no .bgi file is present**, BGInfo runs with `/all` flag showing all default fields.
