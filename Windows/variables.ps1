[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
param()
##*===============================================
## Variables: Deploy-Application.ps1
##*===============================================
[string]$appVendor = ''
[string]$appName = 'Off-Domain Printer Setup'
[string]$appVersion = '2.5.0.0'
[string]$appArch = ''
[string]$appLang = 'EN'
[string]$appRevision = '01'
[string]$appScriptVersion = '1.0.0'
[string]$appScriptDate = '02/21/2024'
[string]$appScriptAuthor = 'Damean Ewan'

## Variables: Install Titles (Only set here to override defaults set by the toolkit)
[string]$installName = ''
[string]$installTitle = ''

## User Defined Variables:
[string]$appsToClose = 'pc-client'
[string]$papercutVersion = '22.1.3' # Papercut - Latest version M:\install\installers\Papercut\Standard
[string]$xdeVersion = '8.110.9.0' # Xerox Desktop Print Experience - https://www.support.xerox.com/en-us/product/altalink-b8000-series/downloads?language=en
[string]$b8065DriverVersion = "7.76.0.0" # PCL6 Print Driver for Administrators - https://www.support.xerox.com/en-us/product/altalink-b8000-series/downloads?language=en
[string]$c8055DriverVersion = "7.76.0.0" # PCL6 Print Driver for Administrators - https://www.support.xerox.com/en-us/product/altalink-c8000-series/downloads?language=en

##*===============================================
## Variables: Import-toConfigMgr.ps1
##*===============================================
$software = @{
    Name                       = $appName
    Version                    = $appVersion
    Publisher                  = $appVendor
    Description                = 'https://michigantechit.atlassian.net/wiki/x/UwFnAg' # The confluence doc tiny link
    Keyword                    = '' # Used to help users find software in Software Center
    LocalizedDescription       = '' # This description will be shown to end users in Software Center
    ContentLocation            = "\\multidrive.mtu.edu\multidrive\install\installers\HuskyPrint\Windows\Pre-Release\$appVersion"
    EstimatedRuntimeMins       = '5'
    MaximumRuntimeMins         = '15' # Minimum of 15
    DetectionMethodConnector   = 'And' # ('And','Or') Logic used to connect multiple detection methods
    SupersededVersion          = '' # The version that needs to be uninstalled before the new version is installed
    UninstallSupersededVersion = $true # *$true or $false Set to true if the application installer cannot gracefully upgrade an existing install of the superseded version
    TargetFolder               = 'Software' # The folder the application should be in
}

## Dependencies declaration
## Uncomment only if your app requires dependencies
$dependencies = @{
    #Group1Name = ('group1App1', 'group1App2')
    #Group2Name = ('group2App')
}
##*===============================================
