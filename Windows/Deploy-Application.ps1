<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

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

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    } Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = ''
    [string]$appName = 'Off-Domain Printer Setup'
    [string]$appVersion = '2.0.0.0'
    [string]$papercutVersion = '19.2.3'
    [string]$appArch = ''
    [string]$appLang = 'EN'
    [string]$appRevision = '01'
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '08/04/2020'
    [string]$appScriptAuthor = 'Eric Boersma'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.2'
    [string]$deployAppScriptDate = '08/05/2020'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    } Else {
        $InvocationInfo = $MyInvocation
    }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        } Else {
            . $moduleAppDeployToolkitMain
        }
    } Catch {
        If ($mainExitCode -eq 0) {
            [int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        } Else {
            Exit $mainExitCode
        }
    }

    # endRegion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    # Installation elapsed start time collection
    $start = (Get-Date)

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

        # pc-client is the Papercut Client process. This needs to be stop to uninstall successfully
        Show-InstallationWelcome -CloseApps 'pc-client' -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

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
        ) # end drivers

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
        #region Printers
        #region Printers
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
        #endregion Printers

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        # Open a browser to show what changes were done to their system
        if ($envUserName -eq "Administrator") {
            Start-Process -FilePath "C:\Program Files\Internet Explorer\iexplore.exe" -ArgumentList $UserReportLog
        } else {
            Start-Process $UserReportLog
        }

        ## Display a message at the end of the install
    } ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        # Show estimated time balloon in minutes
        # <Update this based on the elapsed uninstallation time found in the logs>
        $EstimatedTime = 2
        Show-BalloonTip -BalloonTipText "$EstimatedTime minutes" -BalloonTipTitle 'Estimated Uninstallation Time' -BalloonTipTime '10000'

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        # <Perform Uninstallation tasks here>
        Show-InstallationProgress -StatusMessage "Removing All PaperCut Agent versions..."

        Remove-MSIApplications -Name "PaperCut"
        Remove-File -Path "$envCommonStartUp\PaperCut MF Client.lnk"

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    } ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'

        # <Perform Repair tasks here>
        Show-InstallationProgress -StatusMessage "Repairing $installTitle..."

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>

        ## Display a message at the end of the uninstall
        Show-InstallationProgress -StatusMessage "Done Repairing $installTitle."

    }

    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Write Elapsed Time to Log
    $finish = Get-Date
    $elapsedTime = "{0:hh}:{0:mm}:{0:ss}" -f (New-TimeSpan -Start $start -End $finish)
    Write-Log -Message "Elapsed $deploymentType Time(hh:mm:ss): $elapsedTime" -Source "Elapsed $deploymentType Time" -LogType 'CMTrace'

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
} Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
