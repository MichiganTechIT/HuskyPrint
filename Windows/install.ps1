function Add-Driver {
    param (
        [Parameter(Mandatory)]
        [string]
        $DriverName,

        [Parameter(Mandatory)]
        [string]
        $UserReportLog,

        [Parameter(Mandatory)]
        [string]
        $Source

    )
    $outFile = @{
        FilePath = $UserReportLog
        Append   = $true
    }
    $driverDirectory = "{0}\{1}" -f $envTemp, [guid]::NewGuid()

    Show-InstallationProgress -StatusMessage "Extracting Driver - $($DriverName)..."
    New-Folder -Path $driverDirectory

    Expand-Archive -Path $Source -DestinationPath $driverDirectory
    $infFilePath = (Get-childItem -Path $driverDirectory -File *.inf).FullName

    $output = Invoke-Command -ScriptBlock {
        param(
            [Parameter()]$Source
        )
        & C:\Windows\System32\pnputil.exe -a "$Source"
    } -ArgumentList ($infFilePath)

    [regex]$DriverAdded = '(?i)Published Name\s?:\s*(?<Driver>oem\d+\.inf)'
    $successDriverAdd = $DriverAdded.Match($output)

    if ($successDriverAdd.Success) {
        "<Br />$($driver.name) - <install style='color:green'>Staged</install>" | Out-File @outFile
        try {
            Show-InstallationProgress -StatusMessage "Installing Driver - $($DriverName)..."
            Add-PrinterDriver -InfPath (Get-WindowsDriver -Driver $successDriverAdd.Groups['Driver'].Value -Online).OriginalFileName[0] -Name $DriverName -ErrorAction Stop
            "<Br />$($driver.name) - <install style='color:green'>Installed</install>" | Out-File @outFile
        } catch {
            "<Br />$($driver.name) - <install style='color:red'>Failed to Installed</install>" | Out-File @outFile
        }
    } else {
        "<Br />$($driver.name) - <install style='color:red'>Staging Driver Failed</install>" | Out-File @outFile
    }

    Show-InstallationProgress -StatusMessage "Cleaning up extracted drivers - $DriverName..."
    Remove-Folder -Path $driverDirectory
}

##*===============================================
##* PRE-INSTALLATION
##*===============================================
[string]$installPhase = 'Pre-Installation'

## Show Welcome Message, close apps if required, verify there is enough disk space to complete the install, and persist the prompt
Show-InstallationWelcome -CloseApps 'pc-client' -CheckDiskSpace -PersistPrompt

## Show Progress Message (with the default message)
Show-InstallationProgress

## <Perform Pre-Installation tasks here>
# Create a log file to show at the end of the setup
$userReportLog = "$configToolkitLogDir\PrinterSetup$((Get-Date -Format o) -replace ":", ".").html"
$outFile = @{
    FilePath = $userReportLog
    Append   = $true
}

# Lets create the log file with our initial header
"<h1>System Changes</h1>Here is a detailed report of what changes where made on your system when you ran this script" | Out-File @outFile

## <Perform Pre-Installation tasks here>
#region SoftwareInstall
"<h3>Software Installations</h3>" | Out-File @outFile

$checkPaperCutInstalledVersion = Get-InstalledApplication -Name 'PaperCut'

if ($null -ne $checkPaperCutInstalledVersion -and
            ($checkPaperCutInstalledVersion.DisplayVersion -notcontains "$PaperCutVersion" -or ($checkPaperCutInstalledVersion | measure-object).count -gt 1)) {

    Show-InstallationProgress -StatusMessage "Removing previous PaperCut Agent versions..."
    Remove-MSIApplications -Name "PaperCut" -ExcludeFromUninstall @(, , @('DisplayVersion', $paperCutVersion, 'Contains'))
    if (Test-Path "$envCommonStartUp\PaperCut MF Client.lnk") {
        Remove-File -Path "$envCommonStartUp\PaperCut MF Client.lnk"
        "<Br />PaperCut AutoStart link - <install style='color:red'>Removed</install>" | Out-File @outFile
    } # End test-path AutoStart
    ("<Br />PaperCut Agent {0} - <install style='color:red'>Removed</install>" -f $checkPaperCutInstalledVersion.DisplayVersion) | Out-File @outFile
} # End previous version check/uninstall

$checkPaperCutInstalledVersion = Get-InstalledApplication -Name 'PaperCut'

if ($checkPaperCutInstalledVersion.DisplayVersion -like "$paperCutVersion*") {
            ("<Br />PaperCut MF {0} - <install style='color:green'>Already Installed</install>" -f $checkPaperCutInstalledVersion.DisplayVersion) | Out-File @outFile
} else {
    Show-InstallationProgress -StatusMessage "Extracting PaperCut Agent..."
    # Need to extract PaperCut install files
    $installerDirectory = "{0}\{1}" -f $envTemp, [guid]::NewGuid()
    New-Folder -Path $installerDirectory

    if (Get-Command -Name Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -Path "$dirFiles\Papercut.zip" -DestinationPath $installerDirectory -Force
    } else {
        Add-Type -assembly "system.io.compression.filesystem"
        [io.compression.zipfile]::ExtractToDirectory("$dirFiles\Papercut.zip", $installerDirectory)
    } # end unzip

    Show-InstallationProgress -StatusMessage "Installing PaperCut Agent..."
    Execute-MSI -Action 'Install' -Path "$installerDirectory\pc-client-admin-deploy.msi" -Parameters "/qn /norestart ALLUSERS=1"
    "<Br />PaperCut MF $paperCutVersion - <install style='color:green'>Installed</install>" | Out-File @outFile

    $StartupShortcut = Show-InstallationPrompt -Title 'Papercut AutoRun' -Message "Would you like PaperCut to run on startup?`nOtherwise you'll have to manually start it when you want to print." -ButtonRightText 'Yes' -ButtonLeftText 'No' -Icon Exclamation -PersistPrompt

    if ($StartupShortcut -eq 'yes') {
        New-Shortcut -Path "$envCommonStartUp\PaperCut MF Client.lnk" -TargetPath "$envProgramFiles\PaperCut MF Client\pc-client.exe" -IconLocation "$envProgramFiles\PaperCut MF Client\pc-client.exe" -Description 'PaperCut MF Client' -WorkingDirectory "$envProgramFiles\PaperCut MF Client"
        "<Br />PaperCut MF $paperCutVersion AutoStart - <install style='color:green'>Created</install> - Created link at $envCommonStartUp\PaperCut MF Client.lnk" | Out-File @outFile
    } # end if Autostart

    Show-InstallationProgress -StatusMessage "Cleaning up installation files..."
    Remove-Folder -Path $installerDirectory
} # end

$checkXeroxDesktop = Get-InstalledApplication -Name 'Xerox Desktop Print Experience'
if ($checkXeroxDesktop -and $checkXeroxDesktop.DisplayVersion -eq $xdeVersion) {
    "<Br />Xerox Desktop Experience $($checkXeroxDesktop.DisplayVersion) - <install style='color:green'>Already Installed</install>" | Out-File @outFile
} else {
    Show-InstallationProgress -StatusMessage "Installing Xerox Desktop Print Experience..."
    Execute-MSI -Action 'Install' -Path "$dirFiles\XrxSetup_$($xdeVersion)_x64.msi" -Parameters "/qn"
    "<Br />Xerox Desktop Experience - <install style='color:green'>Installed</install>" | Out-File @outFile
}
#endregion SoftwareInstall

#region Drivers
"<h3>Drivers</h3>" | Out-File @outFile
$drivers = @(
    @{
        Name    = "Xerox AltaLink B8065 V4 PCL6" # husky-bw
        Version = "7.76.0.0"
        Source  = "$dirFiles\Drivers\AltaLinkB80xx_7.76.0.0_PCL6_x64.zip"
    }, @{
        Name    = "Xerox AltaLink C8055 V4 PCL6" # husky-color
        Version = "7.76.0.0"
        Source  = "$dirFiles\Drivers\AltaLinkC80xx_7.76.0.0_PCL6_x64.zip"
    }
)
Show-InstallationProgress -StatusMessage "Checking Printer Drivers..."
foreach ($driver in $drivers) {
    try {
        $installedPrintDriver = Get-PrinterDriver -Name $driver.Name -ErrorAction Stop
        $installedDriverVersion = (Get-WindowsDriver -Online -Verbose:$false -Driver $installedPrintDriver.InfPath)[0].Version

        if ($installedDriverVersion -ne $driver.Version) {
            "<Br />$($driver.name) - <install style='color:orange'>Needs to be Updated</install>" | Out-File @outFile
            # The driver does not match the desired version, it needs to be upgraded
            Add-Driver -DriverName $driver.Name -UserReportLog $userReportLog -Source $driver.Source
        } else {
            "<Br />$($driver.name) - <install style='color:green'>OK</install>" | Out-File @outFile
        }
    } catch {
        # Driver does not exist
        Add-Driver -DriverName $driver.Name -UserReportLog $userReportLog -Source $driver.Source
    }
} # end foreach printer
#endregion Drivers
##*===============================================
##* INSTALLATION
##*===============================================
[string]$installPhase = 'Installation'

## <Perform Installation tasks here>
Show-InstallationProgress -StatusMessage "Installing $installTitle..."

Show-InstallationProgress -StatusMessage "Adding Printers..."
"<h3>Printers</h3>" | Out-File @outFile

$printers = @(
    @{
        Name              = "husky-bw"
        Driver            = "Xerox AltaLink B8065 V4 PCL6"
        Address           = "print.mtu.edu"
        InstalledFeatures = @{
            "Config:InstallableHolePunchUnitActual"      = "PunchUnknown" # Hole punch
            "Config:InstallableInputPaperTraysActual"    = "6TraysHighCapacityTandemTray" # Tray Configuration
            "Config:InstallableOutputDeliveryUnitActual" = "OfficeFinisher" # Finisher Option
        }
    }, @{
        Name              = "husky-color"
        Driver            = "Xerox AltaLink C8055 V4 PCL6"
        Address           = "print.mtu.edu"
        InstalledFeatures = @{
            "Config:InstallableHolePunchUnitActual"      = "Punch_2And_3HoleStack" # hole punch
            "Config:InstallableInputPaperTraysActual"    = "6TraysHighCapacityTandemTray" # Tray Configuration
            "Config:InstallableOutputDeliveryUnitActual" = "TypeSb" # Finisher Option
        }
    }
)

foreach ($printer in $printers) {
    Show-InstallationProgress -StatusMessage "Creating printer ports for $($printer.name)..."

    #Lets check if the printer already exists.
    try {
        $existingPort = Get-PrinterPort -Name $Printer.Name -ErrorAction Stop
    } catch {
        $existingPort = $null
    }

    if ($null -eq $existingPort) {
        # The port does not exist, a new port is needed
        $newPortParams = @{
            Name            = $printer.name
            LprHostAddress  = $printer.Address
            LprQueueName    = $printer.name
            LprByteCounting = $true
            ErrorAction     = 'Stop'
        }
        try {
            Add-PrinterPort @newPortParams
        } catch {
            "<Br />Port: $($printer.name) - <install style='color:red'>Failed</install>" | Out-File @outFile
            continue
        }
        "<Br />Port: $($printer.name) - <install style='color:green'>Added</install>" | Out-File @outFile
    } else {
        $newPrinterPort = @{
            Name = $printer.Name
        } # End newPrinterPort
        # printer port name is already used. Need to validate the settings are in a desired state.
        Show-InstallationProgress -StatusMessage "Validating pre-existing port settings for $($printer.name)..."
        $wmiPrinterQuery = Get-WmiObject -Query "SELECT * FROM Win32_TCPIpPrinterPort WHERE Name='$($Printer.Name)'"
        if ($existingPort.PrinterHostAddress -ne $printer.Address) {
            $newPrinterPort.PrinterHostAddress = $printer.Address
            "<Br />Port: $($printer.name) - <install style='color:green'>Updated Address</install>" | Out-File @outFile
        }

        if ($existingPort.LprQueueName -ne $printer.name) {
            if ($wmiPrinterQuery.Protocol -ne 2) {
                $newPrinterPort.Protocol = 2
                "<Br />Port: $($printer.name) - <install style='color:green'>Converted Port to use LPR protocol</install>" | Out-File @outFile
            }
            $newPrinterPort.lprQueueName = $printer.name
            "<Br />Port: $($printer.name) - <install style='color:green'>Updated QueueName</install>" | Out-File @outFile
        }
        if ($newPrinterPort.count -gt 1) {
            Get-WmiObject -Query ("Select * FROM Win32_TCPIpPrinterPort WHERE Name = '{0}'" -f $printer.name ) | Set-WmiInstance -Arguments $newPrinterPort -PutType UpdateOnly | Out-Null
        } # End If newPrinterPort.Count
    }
    try {
        $existingPrinter = Get-Printer -Name $Printer.Name -ErrorAction 'Stop'
    } catch {
        $existingPrinter = $null
    }

    if ($null -eq $existingPrinter) {
        try {
            Add-Printer -Name $printer.Name -PortName $Printer.Name -DriverName $Printer.Driver -Shared:$false
        } catch {
            "<Br />Printer: $($printer.name) - <install style='color:red'>Failed</install>" | Out-File @outFile
            continue
        }

        "<Br />Printer: $($printer.name) - <install style='color:green'>Added</install>" | Out-File @outFile
    } else {
        #Printer already exists. Need to verify the settings are in a desired state.
        Show-InstallationProgress -StatusMessage "Validating $($printer.name) settings..."
        if ($existingPrinter.Shared) {
            Set-Printer -Name $Printer.Name -Shared:$false
            "<Br />Printer: $($printer.name) - <install style='color:green'>Disabled Sharing</install>" | Out-File @outFile
        }
        if ($existingPrinter.DriverName -ne $printer.Driver) {
            Set-Printer -Name $existingPrinter.Name -DriverName $printer.Driver
            "<Br />Printer: $($printer.name)- <install style='color:green'>Changed Driver to $($printer.driver)</install>" | Out-File @outFile
        }
        if ($existingPrinter.PortName -ne $printer.name) {
            Get-PrintJob -PrinterName $Printer.Name | Remove-PrintJob
            Set-Printer -Name $Printer.Name -PortName $Printer.Name
            "<Br />Printer: $($printer.name) - <install style='color:green'>Changed Port to $($printer.name) from $($existingPrinter.PortName)</install>" | Out-File @outFile
        }
    }
    if ($printer.InstalledFeatures) {
        foreach ($feature in ($printer.InstalledFeatures).GetEnumerator()) {
            $currentFeatureValue = Get-PrinterProperty -PrinterName $printer.name -PropertyName $feature.name
            if ($currentFeatureValue.value -ne $feature.Value) {
                Set-PrinterProperty -PrinterName $printer.name -PropertyName $feature.Name -Value $feature.Value
                "<Br />Printer: $($printer.name) - <install style='color:green'>Setting an Installed Option $($feature.Name)</install>" | Out-File @outFile
            }
        }
    }
    "<Br />Printer: $($printer.name) - <install style='color:green'>OK</install>" | Out-File @outFile
}
##*===============================================
##* POST-INSTALLATION
##*===============================================
[string]$installPhase = 'Post-Installation'

## <Perform Post-Installation tasks here>

## Display a message at the end of the install
Show-InstallationProgress -StatusMessage "Done Installing $installTitle."

if ($envUserName -eq "Administrator") {
    Start-Process -FilePath "C:\Program Files\Internet Explorer\iexplore.exe" -ArgumentList $UserReportLog
} else {
    Start-Process $UserReportLog
}
