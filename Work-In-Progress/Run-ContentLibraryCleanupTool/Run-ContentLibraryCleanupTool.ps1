<#
.SYNOPSIS
    OBS READ THE MS PAGE ABOUT THE TOOL PRIOR TO USING THIS SCRIPT
    
    Use the content library cleanup command-line tool to remove content that's no longer associated with an object on a distribution point. 
    This type of content is called orphaned content.
    
    https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/content-library-cleanup-tool
    
.PARAMETERS
    $ToolPath = Path to the folder containing the "ContentLibraryCleanup.exe", i  move it from the defualt folder, and then run the script.
    $ProviderMachineName = The CM env Server FQDN.
    $SiteCode = Your CM SiteCode.
    $Mode = set the tool to run in either WhatIf, or Delete, read more on MS page.
    $DistributionPoints = Enter one or more to run on specific DP's, leave blank if you want it to run on all your DP's.
    $ExcludedDistributionPoints = Add FQDN's to DPs that you want the tool to NOT run on.
    
.EXAMPLE
    powershell.exe -executionpolicy bypass -file \\cm01\source\Script\Run-ContentCleanupTool.ps1 -ToolPath "\\cm01\source\Script" -ProviderMachineName "CM01.corp.com" -SiteCode "PS1" -Mode "WhatIf"
#>

Param(
    [Parameter(Mandatory = $True,
        HelpMessage = "Enter UNCPath to 'ContentLibraryCleanup.exe' location, e.g \\Server\c$\Temp'")]
    [String]
    $ToolPath,

    [Parameter(Mandatory = $True,
        HelpMessage = "Enter the MECM Server FQDN e.g 'MEMServer.domain.com'")]
    [String]
    $ProviderMachineName,

    [Parameter(Mandatory = $True,
        HelpMessage = "Enter CM SiteCode, e.g 'PS1'")]
    [String]
    $SiteCode,

    [Parameter(Mandatory = $True,
        HelpMessage = "Choose wether to run in WhatIf-mode or Delete-mode, valid input 'WhatIf' or 'Delete'")]
    [String]
    $Mode,

    [Parameter(Mandatory = $False,
        HelpMessage = "Enter the FQDN of a DP if you want the tool ran on just one and not all")]
    $DistributionPoints = @(),

    [Parameter(Mandatory = $False,
    HelpMessage = "Enter the FQDN of a DP if you want the tool ran on just one and not all")]
    $ExcludedDistributionPoints = @(
    "CM01.corp.viamonstra.com"
    )
)

# Customizations
$initParams = @{}
$initParams.Add("ErrorAction", "Stop")

# Import the ConfigurationManager.psd1 module 
if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

Set-Location "$($SiteCode):\" @initParams

# If no DP specified, get all availible DP's in CM Env
if ($DistributionPoints.Count -eq 0) {
    try {
        $DistributionPoints = @(Get-CMDistributionPoint -ErrorAction Stop).NetworkOSPath
    }
    catch {
        Write-Output "Could not get DistributionPoints: $($_.Exception.Message)"; Exit 1
    }
}

Set-Location -Path $env:SystemDrive

If(!(Test-path -Path "$ToolPath\Logs")){
    New-Item -Path "$ToolPath" -Name "logs" -ItemType "directory"
}


$TrimmedDPName = $DistributionPoints.trim("\")

#Set Params and run CleanupTool
foreach ($DP in $TrimmedDPName) {
    if ($DP -in $ExcludedDistributionPoints) {
        Write-Output "$DP found in exceptionlist, skipping..."
    }
    Else {
        $ContentLibCleanupTool = @{
            FilePath = "$ToolPath\ContentLibraryCleanup.exe"
            ArgumentList = @(
                "/DP $DP", `
                "/Mode $Mode", `
                "/q"
            )
            Wait = $true
            Passthru = $true
            RedirectStandardOutput = "$ToolPath\Logs\$DP-LibraryCleanup.log"
        }
        try {
            Start-Process @ContentLibCleanupTool -ErrorAction Stop
        }
        catch {
            Write-Output "Could not start process: $($_.Exception.Message)"; Exit 1
        }
    }
}
