<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
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
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
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
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = ''
	[string]$appName = 'HuskyPrint'
	[string]$appVersion = '1.1.0.0'
	[string]$PaperCutVersion = '18.2.2'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '08/23/2018'
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
	[version]$deployAppScriptVersion = [version]'3.6.9'
	[string]$deployAppScriptDate = '02/12/2017'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}
	
	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

    # Installation elapsed start time collection
	$start = (Get-Date)
	$UserReportLog = "$configToolkitLogDir\PrinterSetup$((Get-Date -Format o) -replace ":", ".").html"
	$outFileParams = @{
		Append = $true
		FilePath = $UserReportLog
	}

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'
		
		## Show Welcome Message, and close the PaperCut agent
		Show-InstallationWelcome -CloseApps 'pc-client' -PersistPrompt
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		#Lets create the log file with our initial header
		"<h1>System Changes</h1>Here is a detailed report of what changes where made on your system when you ran this script" | Out-File @outFileParams
		
		## <Perform Pre-Installation tasks here>
		#region SoftwareInstall
		"<h3>Software Installations</h3>" | Out-File @outFileParams

		$checkPaperCutInstalledVersion = Get-InstalledApplication -Name 'PaperCut'

		if ($null -ne $checkPaperCutInstalledVersion -and ($checkPaperCutInstalledVersion.DisplayVersion -notcontains "$PaperCutVersion" -or ($checkPaperCutInstalledVersion | measure-object).count -gt 1)) {
			Show-InstallationProgress -StatusMessage "Removing previous PaperCut Agent versions..."
			Remove-MSIApplications -Name "PaperCut" -ExcludeFromUninstall @(,,@('DisplayVersion', $PaperCutVersion, 'Contains'))
			if (Test-Path "$envCommonStartUp\PaperCut MF Client.lnk") {
				Remove-File -Path "$envCommonStartUp\PaperCut MF Client.lnk"
				"<Br />PaperCut AutoStart link - <install style='color:red'>Removed</install>" | Out-File @outFileParams
			} # End test-path AutoStart
			("<Br />PaperCut Agent {0} - <install style='color:red'>Removed</install>" -f $checkPaperCutInstalledVersion.DisplayVersion) | Out-File @outFileParams
		} # End previous version check/uninstall

		$checkPaperCutInstalledVersion = Get-InstalledApplication -Name 'PaperCut'

		if ($checkPaperCutInstalledVersion.DisplayVersion -like "$PaperCutVersion*") {
			("<Br />PaperCut MF {0} - <install style='color:green'>Already Installed</install>" -f $checkPaperCutInstalledVersion.DisplayVersion) | Out-File @outFileParams
		} else {
			Show-InstallationProgress -StatusMessage "Extracting PaperCut Agent..."
			# Need to extract PaperCut install files
			$extractLocation = "{0}\{1}" -f $envTemp,[guid]::NewGuid()
			New-Folder -Path $extractLocation

			if (get-command -Name Expand-Archive -ErrorAction SilentlyContinue) {
				Expand-Archive -Path "$dirFiles\Papercut.$PaperCutVersion.zip" -DestinationPath $extractLocation -Force
			} else {
				Add-Type -assembly "system.io.compression.filesystem"
				[io.compression.zipfile]::ExtractToDirectory("$dirFiles\Papercut.$PaperCutVersion.zip", $extractLocation)
			} # End unzip

			Show-InstallationProgress -StatusMessage "Installing PaperCut Agent..."
			Execute-MSI -Action 'Install' -Path "$extractLocation\pc-client-admin-deploy.msi" -Parameters "/qn /norestart ALLUSERS=1"
			"<Br />PaperCut MF $PaperCutVersion - <install style='color:green'>Installed</install>" | Out-File @outFileParams

			$StartupShortcut = Show-InstallationPrompt -Title 'Papercut AutoRun' -Message "Would you like PaperCut to run on startup?`nOtherwise you'll have to manually start it when you want to print." -ButtonRightText 'Yes' -ButtonLeftText 'No' -Icon Exclamation -PersistPrompt 
			
			if($StartupShortcut -eq 'yes') {
				New-Shortcut -Path "$envCommonStartUp\PaperCut MF Client.lnk" -TargetPath "$envProgramFilesX86\PaperCut MF Client\pc-client.exe" -IconLocation "$envProgramFilesX86\PaperCut MF Client\pc-client.exe" -Description 'PaperCut MF Client' -WorkingDirectory "$envProgramFilesX86\PaperCut MF Client"
				"<Br />PaperCut MF $PaperCutVersion AutoStart - <install style='color:green'>Created</install> - Created link at $envCommonStartUp\PaperCut MF Client.lnk" | Out-File @outFileParams
			} # End if Autostart

			Show-InstallationProgress -StatusMessage "Cleaning up installation files..."
			Remove-Folder -Path $extractLocation
		}
		
		#region Drivers
		"<h3>Drivers</h3>" | Out-File @outFileParams
		switch -wildcard ($envOSVersion) {
			'6.1*' {  
				#Windows 7
				$drivers = @(
					@{
						Name = "Xerox AltaLink B8065 PCL6" # husky-bw
						Source = "$dirFiles\Drivers\ALB80XX_5.528.10.0_PCL6_x64.zip"
					},@{
						Name = "Xerox AltaLink C8055 PCL6" # husky-color
						Source = "$dirFiles\Drivers\ALC80XX_5.528.10.0_PCL6_x64.zip"
					}
				)
			}
			default {
				$drivers = @(
					@{
						Name = "Xerox AltaLink B8065 V4 PCL6" # husky-bw
						Version = "6.250.0.0"
						Source = "$dirFiles\Drivers\XeroxAltaLinkB80xx_6.250.0.0_PCL6_x64.zip"
					},@{
						Name = "Xerox AltaLink C8055 V4 PCL6" # huksy-color
						Version = "6.250.0.0"
						Source = "$dirFiles\Drivers\XeroxAltaLinkC80xx_6.250.0.0_PCL6_x64.zip"
					}
				)
			}	
		}	
		
		Show-InstallationProgress -StatusMessage "Adding printer drivers..."
		foreach ($driver in $drivers) {
			switch -wildcard ($envOSVersion) {
				'6.1*' {  
					#Windows 7
					Show-InstallationProgress -StatusMessage ("Extracting driver {0}" -f $driver.Name)
					$extractLocation = "{0}\{1}" -f $envTemp,[guid]::NewGuid()
					New-Folder -Path $extractLocation
					
					if (get-command -Name Expand-Archive -ErrorAction SilentlyContinue) {
						Expand-Archive -Path $driver.source -DestinationPath $extractLocation -Force
					} else {
						Add-Type -assembly "system.io.compression.filesystem"
						[io.compression.zipfile]::ExtractToDirectory($driver.source, $extractLocation)
					} # End unzip

					$driverInf = (Get-childItem -Path $extractLocation -File *.inf).FullName

					cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\prndrvr.vbs" -a -m "$($driver.name)" -i $driverInf
					"<Br />$($driver.name) - <install style='color:green'>Installed</install>" | Out-File @outFileParams
					
					Show-InstallationProgress -StatusMessage "Cleaning up installation files..."
					Remove-Folder -Path $extractLocation
				}
				default {
					$installDriver = $true
					$InstalledPrintDriver = Get-PrinterDriver -Name $driver.name
					if($InstalledPrintDriver){
						$installedDriver = Get-WindowsDriver -Online -Verbose:$false -Driver $InstalledPrintDriver.InfPath
						if($installedDriver.Version -ne $driver.version){
							"<Br />Driver {0} version does not match - <install style='color:red'>Current: {1}, Desired: {2}</install>" -f $driver.name,$installedDriver.version,$driver.version| Out-File @outFileParams
							$installDriver = $true
						} else {
							"<Br />$($driver.name) - <install style='color:green'>OK</install>" | Out-File @outFileParams
							$installDriver = $false
							continue
						}
					}

					if ($installDriver) {
						Show-InstallationProgress -StatusMessage ("Extracting driver {0}" -f $driver.Name)
						$extractLocation = "{0}\{1}" -f $envTemp,[guid]::NewGuid()
						New-Folder -Path $extractLocation
						
						if (get-command -Name Expand-Archive -ErrorAction SilentlyContinue) {
							Expand-Archive -Path $driver.source -DestinationPath $extractLocation -Force
						} else {
							Add-Type -assembly "system.io.compression.filesystem"
							[io.compression.zipfile]::ExtractToDirectory($driver.source, $extractLocation)
						} # End unzip

						$driverInf = (Get-childItem -Path $extractLocation -File *.inf).FullName

						Show-InstallationProgress -StatusMessage ("Staging driver {0}" -f $driver.Name)

						$output = Invoke-Command -ScriptBlock {
                            param(
                                [Parameter()]$Driver
                            )
                            & "C:\Windows\System32\pnputil.exe" -a "$Driver"
						} -ArgumentList ($driverInf)
						
						[regex]$driverAdded = '(?i)Published Name\s?:\s*(?<Driver>oem\d+\.inf)'
                		$successDriverAdd = $driverAdded.Match($output)
						if ($successDriverAdd.Success) {
							"<Br />{0} - <install style='color:green'>Staged</install>" -f $driver.Name | Out-File @outFileParams
							$driverSource = (Get-WindowsDriver -Driver $successDriverAdd.Groups['Driver'].Value -Online).OriginalFileName[0]
						} else {						
							"<Br />{0} - <install style='color:red'>Failed to Stage</install>" -f $driver.Name | Out-File @outFileParams
							continue
						} # End driver add check

						try {
							Add-PrinterDriver -InfPath $driverSource  -Name $driver.name -ErrorAction Stop
						} catch {
							"<Br />{0} - <install style='color:red'>Failed to Install</install>" -f $driver.Name | Out-File @outFileParams
							break
						}
						"<Br />{0} - <install style='color:green'>Installed</install>" -f $driver.Name | Out-File @outFileParams
						Show-InstallationProgress -StatusMessage "Cleaning up installation files..."
						Remove-Folder -Path $extractLocation
					} # End install driver block
				} # End default
			} # End switch
		} # End foreach driver
		#endregion Drivers
<#
		#region Printers
		Show-InstallationProgress -StatusMessage "Adding Printers..."
		"<h3>Printers</h3>" | Out-File -Append -FilePath $UserReportLog
		switch -wildcard ($envOSVersion) {
			'6.1*' {  
				$Printers = @(
					@{
						Name = "husky-bw"
						Driver = "Xerox WorkCentre 5865 PCL6"
						Address = "print.mtu.edu"
					},@{
						Name = "husky-color"
						Driver = "Xerox WorkCentre 7855 PCL6"
						Address = "print.mtu.edu"
					}
				)
			}
			default{
				$Printers = @(
					@{
						Name = "husky-bw"
						Driver = "Xerox WorkCentre 5865 V4 PCL6"
						Address = "print.mtu.edu"
						InstalledFeatures = @{
							"Config:InstallableHolePunchUnitActual"="PunchUnknown" # Hole punch
							"Config:InstallableInputPaperTraysActual"="6TraysHighCapacityTandemTray" # Tray Configuration
							"Config:InstallableOutputDeliveryUnitActual"="OfficeFinisher" # Finisher Option
						}
					},@{
						Name = "husky-color"
						Driver = "Xerox WorkCentre 7855 V4 PCL6"
						Address = "print.mtu.edu"
						InstalledFeatures = @{
							"Config:InstallableHolePunchUnitActual"="Punch_2And_3HoleStack" # hole punch
							"Config:InstallableInputPaperTraysActual"="6TraysHighCapacityTandemTray" # Tray Configuration
							"Config:InstallableOutputDeliveryUnitActual"="TypeSb" # Finisher Option
						}
					}
				)
			}
		}
		
		foreach ($printer in $printers) {
			Show-InstallationProgress -StatusMessage "Creating printer ports for $($printer.name)..."
			switch -wildcard ($envOSVersion) {
				'6.1*' {  
					cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\Prnport.vbs" -a -r $printer.name -h $printer.Address -o lpr -q $printer.name
					"<Br />Port: $($printer.name) - <install style='color:green'>Added</install>" | Out-File -Append -FilePath $UserReportLog
					cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs" -a -p "$($printer.name)" -m "$($printer.Driver)" -r "$($printer.name)"
					"<Br />Printer: $($printer.name) - <install style='color:green'>Added</install>" | Out-File -Append -FilePath $UserReportLog
				}
				default {
					#Lets check if the printer already exists.
					$existingPort = Get-PrinterPort -Name $Printer.Name -ErrorAction SilentlyContinue
					if(!$existingPort){
						try {
							Add-PrinterPort -Name $Printer.Name -LprHostAddress $Printer.Address -LprQueueName $Printer.Name -LprByteCounting:$true
						} catch {
							"<Br />Port: $($printer.name) - <install style='color:red'>Failed</install>" | Out-File -Append -FilePath $UserReportLog
							continue
						}
						"<Br />Port: $($printer.name) - <install style='color:green'>Added</install>" | Out-File -Append -FilePath $UserReportLog
					} else {
						#printer portname is already used. Need to validate the settings are in a desired state. 
						Show-InstallationProgress -StatusMessage "Validating pre-existing port settings for $($printer.name)..."
						if($existingPort.PrinterHostAddress -ne $printer.Address){
							$wmiPrinterQuery = Get-WmiObject -Query "SELECT * FROM Win32_TCPIpPrinterPort WHERE Name='$($Printer.Name)'"
							$wmiPrinterQuery.HostAddress=$printer.Address
							$wmiPrinterQuery.put() | Out-Null
							"<Br />Port: $($printer.name) - <install style='color:green'>Updated Address</install>" | Out-File -Append -FilePath $UserReportLog
						}
						if($existingPort.LprQueueName -ne $printer.name){
							$wmiPrinterQuery = Get-WmiObject -Query "SELECT * FROM Win32_TCPIpPrinterPort WHERE Name='$($Printer.Name)'"
							if($wmiPrinterQuery.Protocol -ne 2){
								$wmiPrinterQuery.Protocol=2
								"<Br />Port: $($printer.name) - <install style='color:green'>Converted Port to use LPR protocol</install>" | Out-File -Append -FilePath $UserReportLog
							}
							$wmiPrinterQuery.Queue="$($Printer.Name)"
							$wmiPrinterQuery.put() | Out-Null
							"<Br />Port: $($printer.name) - <install style='color:green'>Updated QueueName</install>" | Out-File -Append -FilePath $UserReportLog
						}
					}
					$existingPrinter = Get-Printer -Name $Printer.Name -ErrorAction SilentlyContinue
					if(!$existingPrinter){
						try {
							Add-Printer -Name $printer.Name -PortName $Printer.Name -DriverName $Printer.Driver -Shared:$false
						} catch {
							"<Br />Printer: $($printer.name) - <install style='color:red'>Failed</install>" | Out-File -Append -FilePath $UserReportLog
							continue
						}
						
						"<Br />Printer: $($printer.name) - <install style='color:green'>Added</install>" | Out-File -Append -FilePath $UserReportLog
					} else {
						#Printer already exists. Need to verify the settings are in a desired state. 
						Show-InstallationProgress -StatusMessage "Validating $($printer.name) settings..."
						if($existingPrinter.Shared){
							Set-Printer -Name $Printer.Name -Shared:$false
							"<Br />Printer: $($printer.name) - <install style='color:green'>Disabled Sharing</install>" | Out-File -Append -FilePath $UserReportLog
						}
						if($existingPrinter.DriverName -ne $printer.Driver){
							Set-Printer -Name $$existingPrinter.Name -DriverName $printer.Driver
							"<Br />Printer: $($printer.name)- <install style='color:green'>Changed Driver to $($printer.driver)</install>" | Out-File -Append -FilePath $UserReportLog
						}
						if($existingPrinter.PortName -ne $printer.name){
							Get-PrintJob -PrinterName $Printer.Name | Remove-PrintJob
							Set-Printer -Name $Printer.Name -PortName $Printer.Name
							"<Br />Printer: $($printer.name) - <install style='color:green'>Changed Port to $($printer.name) from $($exisistingPrinter.PortName)</install>" | Out-File -Append -FilePath $UserReportLog
						}
						"<Br />Printer: $($printer.name) - <install style='color:green'>OK</install>" | Out-File -Append -FilePath $UserReportLog
					}
					if($printer.InstalledFeatures){
						foreach ($feature in ($printer.InstalledFeatures).GetEnumerator()){
							$currentFeatureValue = Get-PrinterProperty -PrinterName $printer.name -PropertyName $feature.name
							if($currentFeatureValue.value -ne $feature.Value){
								Set-PrinterProperty -PrinterName $printer.name -PropertyName $feature.Name -Value $feature.Value
								"<Br />Printer: $($printer.name) - <install style='color:green'>Setting an Installed Option $($feature.Name)</install>" | Out-File -Append -FilePath $UserReportLog
							}
						}
					}
				}
			}
		}
		if($envOSVersion -like '6.1*'){
			Start-Process "http://support.it.mtu.edu/981790941"
		}
		#endregion Printers

		#region PrinterConversion
		#Lets look at the existing printers that are configured to use IPP printing and convert them to use the new servers and use the new protocol.
		Show-InstallationProgress -StatusMessage "Converting exising printers..."
		"<h3>Printer Conversion</h3>" | Out-File -Append -FilePath $UserReportLog
		switch -wildcard ($envOSVersion) {
			'6.1*' {  
				$convertPrinters = Get-WmiObject -Class Win32_Printer -Filter {Name like "%printing.it.mtu.edu%"}
				if(!$convertPrinters){ 
					break
				}
				foreach($convertPrinter in $convertPrinters){
					$NewQueueName = (($convertPrinter.Name).Split("\"))[-1]
					if($NewQueueName -eq "husky-bw" -or $NewQueueName -eq "husky-color"){
						$convertPrinter.CancelAllJobs()
						cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs" -d -p "$($convertPrinter.Name)"
						"<Br />Printer: $($convertPrinter.Name) - <install style='color:red'>Removed</install>" | Out-File -Append -FilePath $UserReportLog
					}else{
						cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\Prnport.vbs" -a -r $NewQueueName -h "print.mtu.edu" -o lpr -q $NewQueueName
						"<Br />Port: $NewQueueName - <install style='color:green'>Added</install>" | Out-File -Append -FilePath $UserReportLog
						$convertPrinter.CancelAllJobs()
						$convertPrinter.RenamePrinter("$NewQueueName")
						"<Br />Printer: $NewQueueName - <install style='color:green'>Renamed from $($convertPrinter.Name)</install>" | Out-File -Append -FilePath $UserReportLog
						Stop-Service -Name Spooler -Force
						# Need to do this hackish method due to how Internet Printers can't change the ports in a standard fashion. Adjusting it though WMI failed so had to hack the registry.
						Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\$NewQueueName" -Name 'Port' -Value $NewQueueName -Type String
						"<Br />Printer: $NewQueueName - <install style='color:green'>Changed port</install>" | Out-File -Append -FilePath $UserReportLog
						Start-Service -Name Spooler
					}
				}
			}
			default {
				$convertPrinters = Get-Printer
				foreach($convertPrinter in $convertPrinters){
					if($convertPrinter.Name -like "*printing.it*" -or $convertPrinter.PortName -like "*printing.it*"){
						Show-InstallationProgress -StatusMessage "Converting $($convertPrinter.Name)..."
						#Lets parse out the queue name
						$NewQueueName = (($convertPrinter.Name).Split("\"))[-1]
						if($NewQueueName -eq "husky-bw" -or $NewQueueName -eq "husky-color"){
							Get-PrintJob -PrinterName $convertPrinter.Name | Remove-PrintJob
							Remove-Printer -Name $convertPrinter.Name
							"<Br />Printer: $($convertPrinter.Name) - <install style='color:red'>Removed</install>" | Out-File -Append -FilePath $UserReportLog
							continue
						}
						if(Get-PrinterPort -Name $NewQueueName -ErrorAction SilentlyContinue){
							$wmiPrinterQuery = Get-WmiObject -Query "SELECT * FROM Win32_TCPIpPrinterPort WHERE Name='$NewQueueName'"
							if($wmiPrinterQuery.Protocol -ne 2){
								$wmiPrinterQuery.Protocol=2
								"<Br />Port: $NewQueueName - <install style='color:green'>Converted Port to use LPR protocol</install>" | Out-File -Append -FilePath $UserReportLog
							}
							$wmiPrinterQuery.HostAddress="print.mtu.edu"
							"<Br />Port: $NewQueueName - <install style='color:green'>Updated Address</install>" | Out-File -Append -FilePath $UserReportLog
							$wmiPrinterQuery.Queue="$NewQueueName"
							"<Br />Port: $NewQueueName - <install style='color:green'>Updated QueueName</install>" | Out-File -Append -FilePath $UserReportLog
							$wmiPrinterQuery.put() | Out-Null
						}else {
							Add-PrinterPort -Name $NewQueueName -LprHostAddress "print.mtu.edu" -LprQueueName $NewQueueName -LprByteCounting:$true
							"<Br />Port: $NewQueueName - <install style='color:green'>Created New Port</install>" | Out-File -Append -FilePath $UserReportLog
						}
							
						Get-PrintJob -PrinterName $convertPrinter.Name | Remove-PrintJob
						Rename-Printer -Name $convertPrinter.Name -NewName $NewQueueName
						"<Br />Printer: $NewQueueName - <install style='color:green'>Renamed from $($convertPrinter.Name)</install>" | Out-File -Append -FilePath $UserReportLog
						Stop-Service -Name Spooler -Force
						# Need to do this hackish method due to how Internet Printers can't change the ports in a standard fashion. Adjusting it though WMI failed so had to hack the registry.
						Set-RegistryKey -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\$NewQueueName" -Name 'Port' -Value $NewQueueName -Type String
						"<Br />Printer: $NewQueueName - <install style='color:green'>Changed port</install>" | Out-File -Append -FilePath $UserReportLog
						Start-Service -Name Spooler
						Remove-PrinterPort -Name $convertPrinter.PortName
						
					}
				}
			}
		}
		#>
		#endregion PrinterConversion
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
		
		## Handle Zero-Config MSI Installations
		#If ($useDefaultMsi) {
		#	[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
		#	Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		#}
		
		## <Perform Installation tasks here>
		if($envUserName -eq "Administrator"){
			Start-Process -FilePath "C:\Program Files\Internet Explorer\iexplore.exe" -ArgumentList $UserReportLog
		} else {
			Start-Process $UserReportLog
		}
		
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>
		
		## Display a message at the end of the install
		#If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		# Show estimated time balloon in minutes
        # <Update this based on the elasped uninstallation time found in the logs>
		$EstimatedTime = 2
		Show-BalloonTip -BalloonTipText "$EstimatedTime minutes" -BalloonTipTitle 'Estimated Uninstallation Time' -BalloonTipTime '10000'

		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
		
		## Handle Zero-Config MSI Uninstallations
		#If ($useDefaultMsi) {
		#	[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
		#	Execute-MSI @ExecuteDefaultMSISplat
		#}
		
		# <Perform Uninstallation tasks here>
		
		
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
	$Elapsedtime = "{0:hh}:{0:mm}:{0:ss}" -f (New-TimeSpan -Start $start -End $finish)
	Write-Log -Message "Elapsed $deploymentType Time(hh:mm:ss): $Elapsedtime" -Source "Elapsed $deploymentType Time" -LogType 'CMTrace'
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}