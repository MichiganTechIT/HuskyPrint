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
    [ValidateSet('Install', 'Uninstall')]
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
        $InfFilePath,

        [Parameter(Mandatory)]
        [string]
        $DriverName,

        [Parameter(Mandatory)]
        [string]
        $UserReportLog,

        [Parameter(Mandatory)]
        [string]
        $DriverArchiveFile

    )
    $outFile = @{
        FilePath = $UserReportLog
        Append   = $true
    }
    Show-InstallationProgress -StatusMessage "Extracting Driver - $($DriverName)..."
    $driverDirectory = Split-Path $infFilePath
    New-Folder -Path $driverDirectory


    Expand-Archive -Path $DriverArchiveFile -DestinationPath $driverDirectory


    $output = Invoke-Command -ScriptBlock {
        param(
            [Parameter()]$Source
        )
        & C:\Windows\System32\pnputil.exe -a "$Source"
    } -ArgumentList ($InfFilePath)

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
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = 'EN'
    [string]$appRevision = '01'
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '07/02/2019'
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
    [version]$deployAppScriptVersion = [version]'3.7.0'
    [string]$deployAppScriptDate = '02/13/2018'
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

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    # Installation elapsed start time collection
    $start = (Get-Date)

    If ($deploymentType -ine 'Uninstall') {
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

        $paperCutVersion = '19.0.3'

        #Lets create the log file with our initial header

        "<h1>System Changes</h1>Here is a detailed report of what changes where made on your system when you ran this script" | Out-File @outFile

        ## <Perform Pre-Installation tasks here>
        #region SoftwareInstall
        "<h3>Software Installations</h3>" | Out-File -Append -FilePath $UserReportLog
        if (Get-InstalledApplication -Name 'PaperCut') {
            Show-InstallationProgress -StatusMessage "Removing previous PaperCut Agent versions..."
            Remove-MSIApplications -Name "PaperCut" -ExcludeFromUninstall @(, , @('DisplayVersion', '19.0.3', 'Exact'))

            # Need to go through Program Files to make sure Papercut was not installed using the .exe as the uninstall is different
            $paperCutDirectories = (Get-ChildItem $envProgramFilesX86, $envProgramFiles -Directory -Filter "PaperCut*").FullName
            if ($null -ne $paperCutDirectory) {
                foreach ($paperCutDirectory in $paperCutDirectories) {
                    if (Test-Path -Path "$paperCutDirectory\unins000.exe") {
                        Execute-Process -Path "$paperCutDirectory\unins000.exe" -Parameters '/VERYSILENT'
                    }
                }
            }
            "<Br />Previous PaperCut Agent - <install style='color:red'>Removed</install>" | Out-File @outFile
        }

        if (Get-InstalledApplication -ProductCode '{23FE50A1-67BD-11E9-AA17-DE30237607C3}') {
            "<Br />PaperCut MF $paperCutVersion - <install style='color:green'>Already Installed</install>" | Out-File @outFile
        } else {
            Show-InstallationProgress -StatusMessage "Extracting PaperCut Agent..."
            # Create a folder where the PaperCut installer can be extracted to
            $paperCutInstallerDirectory = "{0}\{1}" -f $envTemp, [guid]::NewGuid().ToString()
            New-Folder -Path $paperCutInstallerDirectory

            # Window 10 has builtin command to expand an archive file. Windows 7 requires alternate method
            try {
                Expand-Archive -Path "$dirFiles\PaperCut.zip" -DestinationPath $paperCutInstallerDirectory
            } catch {
                [System.IO.Compression.ZipFile]::ExtractToDirectory("$dirFiles\PaperCut.zip", $paperCutInstallerDirectory)
            }

            Show-InstallationProgress -StatusMessage "Installing PaperCut Agent..."
            Execute-MSI -Action 'Install' -Path "$paperCutInstallerDirectory\pc-client-admin-deploy.msi" -Parameters "/qn /norestart ALLUSERS=1"
            "<Br />PaperCut MF $paperCutVersion - <install style='color:green'>Installed</install>" | Out-File @outFile

            $StartupShortcut = Show-InstallationPrompt -Title 'Papercut AutoRun' -Message "Would you like PaperCut to run on startup?`nOtherwise you'll have to manually start it when you want to print." -ButtonRightText 'Yes' -ButtonLeftText 'No' -Icon Exclamation -PersistPrompt
            if ($StartupShortcut -eq 'yes') {
                New-Shortcut -Path "$envCommonStartUp\PaperCut MF Client.lnk" -TargetPath "$envProgramFiles\PaperCut MF Client\pc-client.exe" -IconLocation "$envProgramFiles\PaperCut MF Client\pc-client.exe" -Description 'PaperCut MF Client' -WorkingDirectory "$envProgramFilesX86\PaperCut MF Client"
                "<Br />PaperCut MF $paperCutVersion AutoStart - <install style='color:green'>Created</install> - Created link at $envCommonStartUp\PaperCut MF Client.lnk" | Out-File @outFile
            }

            Show-InstallationProgress -StatusMessage "Cleaning up installation files for PaperCut Agent..."
            Remove-Folder -Path $paperCutInstallerDirectory
        }

        #endregion SoftwareInstall

        #region Drivers
        "<h3>Drivers</h3>" | Out-File @outFile
        switch -wildcard ($envOSVersion) {
            '6.1*' {
                #Windows 7
                $drivers = @(
                    @{
                        Name   = 'Xerox AltaLink B8065 PCL6' # husky-bw
                        Source = "$dirFiles\Drivers\AltaLinkB80xx_5.639.3.0_PCL6_x64_v3.zip"
                        File   = 'x3ASNOX.inf'
                    }, @{
                        Name   = "Xerox AltaLink C8055 PCL6"
                        Source = "$dirFiles\Drivers\AltaLinkC80xx_5.639.3.0_PCL6_x64_v3.zip"
                        File   = 'x3ASKYX.inf'
                    }
                ) # end drivers
            } # end 6.1
            default {
                $drivers = @(
                    @{
                        Name    = "Xerox AltaLink B8065 V4 PCL6"
                        Version = "7.76.0.0"
                        Source  = "$dirFiles\Drivers\AltaLinkB80xx_7.76.0.0_PCL6_x64.zip"
                        File    = 'XeroxAltaLinkB80xx_PCL6.inf'
                    }, @{
                        Name    = "Xerox AltaLink C8055 V4 PCL6"
                        Version = "7.76.0.0"
                        Source  = "$dirFiles\Drivers\AltaLinkC80xx_7.76.0.0_PCL6_x64.zip"
                        File    = 'XeroxAltaLinkC80xx_PCL6.inf'
                    }
                ) # end drivers
            } # end default
        } # end switch

        Show-InstallationProgress -StatusMessage "Checking Printer Drivers..."
        foreach ($driver in $drivers) {
            $driverDirectory = "{0}\{1}" -f $envTemp, [guid]::NewGuid().ToString()
            switch -wildcard ($envOSVersion) {
                '6.1*' {
                    #Windows 7
                    New-Folder -Path $driverDirectory
                    Show-InstallationProgress -StatusMessage "Extracting Driver $($driver.Name)..."
                    # Window 10 has builtin command to expand an archive file. Windows 7 requires alternate method depending on PowerShell version installed
                    try {
                        Expand-Archive -Path $driver.Source -DestinationPath $driverDirectory
                    } catch {
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($driver.Source, $driverDirectory)
                    }

                    cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\prndrvr.vbs" -a -m "$($driver.name)" -i "$($driverDirectory)\$($driver.File)"
                    "<Br />$($driver.name) - <install style='color:green'>Installed</install>" | Out-File @outFile

                    Show-InstallationProgress -StatusMessage "Cleaning up driver files..."
                    Remove-Folder -Path $driverDirectory
                } # end 6.1
                default {
                    $infFilePath = Join-Path -Path $driverDirectory -ChildPath $driver.File

                    try {
                        $installedPrintDriver = Get-PrinterDriver -Name $driver.Name -ErrorAction Stop
                        $installedDriverVersion = (Get-WindowsDriver -Online -Verbose:$false -Driver $installedPrintDriver.InfPath)[0].Version

                        if ($installedDriverVersion -ne $driver.Version) {
                            "<Br />$($driver.name) - <install style='color:orange'>Needs to be Updated</install>" | Out-File @outFile
                            # The driver does not match the desired version, it needs to be upgraded
                            Add-Driver -InfFilePath $infFilePath -DriverName $driver.Name -UserReportLog $userReportLog -DriverArchiveFile $driver.Source
                        } else {
                            "<Br />$($driver.name) - <install style='color:green'>OK</install>" | Out-File @outFile
                        }
                    } catch {
                        # Driver does not exist
                        Add-Driver -InfFilePath $infFilePath -DriverName $driver.Name -UserReportLog $userReportLog -DriverArchiveFile $driver.Source
                    }
                } # end default
            } # end switch
        } # end foreach printer
        #endregion Drivers

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        ## <Perform Installation tasks here>


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


    }

    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

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
