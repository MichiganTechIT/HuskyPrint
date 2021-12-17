##*===============================================
##* PRE-UNINSTALLATION
##*===============================================
[string]$installPhase = 'Pre-Uninstallation'

## Show Progress Message (with the default message)
Show-InstallationProgress

## <Perform Pre-Uninstallation tasks here>

##*===============================================
##* UNINSTALLATION
##*===============================================
[string]$installPhase = 'Uninstallation'

# <Perform Uninstallation tasks here>
Show-InstallationProgress -StatusMessage "Removing All PaperCut Agent versions..."

Remove-MSIApplications -Name "PaperCut"
Remove-File -Path "$envCommonStartUp\PaperCut MF Client.lnk"

Show-InstallationProgress -StatusMessage "Removing Xerox Desktop Print Experience..."
Remove-MSIApplications -Name 'Xerox Desktop Print Experience'
##*===============================================
##* POST-UNINSTALLATION
##*===============================================
[string]$installPhase = 'Post-Uninstallation'

## <Perform Post-Uninstallation tasks here>

## Display a message at the end of the uninstall
Show-InstallationProgress -StatusMessage "Done Uninstalling $installTitle."
