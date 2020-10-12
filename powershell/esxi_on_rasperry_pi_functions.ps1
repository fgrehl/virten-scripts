function Write-RpiEepromToUsb {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [string]$eepromUrl = "https://github.com/raspberrypi/rpi-eeprom/releases/download/v2020.09.03-138a1/rpi-boot-eeprom-recovery-2020-09-03-vl805-000138a1.zip"
    )

    $Elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $Elevated) {
        Throw "This Function requires Elevation"
    }
    
    $eepromDisk = Get-Disk | Where-Object {$_.BusType -eq 'USB' -or $_.BusType -eq 7}  | Out-GridView -Title 'Select SD Card for RPi EEPROM' -OutputMode Single | Clear-Disk -RemoveData -RemoveOEM -PassThru | New-Partition -UseMaximumSize -IsActive -AssignDriveLetter | Format-Volume -FileSystem FAT32
    if($null -eq $eepromDisk) {
        Throw "No USB Device found."
    }

    # Download EEPROM
    $eepromFile = ($env:TEMP)+"\"+(Split-Path $eepromUrl -leaf)
    Invoke-WebRequest -Uri $eepromUrl -OutFile $eepromFile
    
    If (-not (Test-Path $eepromFile)){
        Throw "EEPROM Image Download Error."
    }
    # Write EEPROM Image to SD Card
    Expand-Archive -LiteralPath $eepromFile -DestinationPath "$($eepromDisk.DriveLetter):\"

    Write-Host "Raspberry Pi 4 EEPROM bootloader rescue image written successfully" 
    Write-Host "1. Remove the SD Card from your PC"
    Write-Host "2. Insert the SD Card to your Raspberry Pi"
    Write-Host "3. Power on Raspberry Pi"
    Write-Host "4. Wait at least 10 seconds."
    Write-Host "If successful, the green LED light will blink rapidly (forever), otherwise an error pattern will be displayed."
    Write-Host "If a HDMI display is attached then screen will display green for success or red if failure a failure occurs."
}


function Write-RpiFirmwareToUsb {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)][string]$rpiFwUrl = "https://github.com/raspberrypi/firmware/archive/master.zip",
        [Parameter(Mandatory=$false)][string]$rpiUefiUrl = "https://github.com/pftf/RPi4/releases/download/v1.20/RPi4_UEFI_Firmware_v1.20.zip"

    )
    $Elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $Elevated) {
        Throw "This Function requires Elevation"
    }

    $firmwareDisk = Get-Disk | Where-Object {$_.BusType -eq 'USB' -or $_.BusType -eq 7} | Out-GridView -Title 'Select SD Card for RPi UEFI Firmware' -OutputMode Single | Clear-Disk -RemoveData -RemoveOEM -PassThru | New-Partition -UseMaximumSize -IsActive -AssignDriveLetter | Format-Volume -FileSystem FAT32
    if($null -eq $firmwareDisk) {
        Throw "No USB Device found."
    }

    # Raspberry Pi Firmware
    $rpiFwPath = ($env:TEMP)+"\rpi\"
    $rpiFwFile = $rpiFwPath+(Split-Path $rpiFwUrl -leaf)
    if (!(Test-Path $rpiFwPath)) {New-Item -Path $rpiFwPath -ItemType Directory |Out-Null}
    Invoke-WebRequest -Uri $rpiFwUrl -OutFile $rpiFwFile
    Expand-Archive -LiteralPath $rpiFwFile -DestinationPath "$($rpiFwPath)" -ErrorAction "SilentlyContinue"
    Remove-Item "$($rpiFwPath)firmware-master\boot\kernel*.img"
    Copy-Item -Path "$($rpiFwPath)firmware-master\boot\*" -Destination "$($firmwareDisk.DriveLetter):\" -Recurse

    # Raspberry Pi UEFI Firmware
    $rpiUefiFile = $rpiFwPath+(Split-Path $rpiUefiUrl -leaf)
    Invoke-WebRequest -Uri $rpiUefiUrl -OutFile $rpiUefiFile
    Expand-Archive -LiteralPath $rpiUefiFile -DestinationPath "$($firmwareDisk.DriveLetter):\" -Force
    Remove-Item -Path $rpiFwPath -Recurse -Confirm:$false

    Write-Host "Raspberry Pi 4 EFI Firmware written successfully"
    Write-Host "1. Remove the SD Card from your PC"
    Write-Host "2. Insert the SD Card to your Raspberry Pi"
    Write-Host "3. Power on Raspberry Pi"
    Write-Host "4. Press ESC to enter Setup"
    Write-Host "5. Disable 3 GB RAM Limit (Device Manager > Raspberry Pi Configuration > Advanced Configuration > Limit RAM to 3 GB)"
    Write-Host "6. Press F10 to save"
    Write-Host "You are now ready to Install ESXi."

}
