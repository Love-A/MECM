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
    $DistributionPoints = @()
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

# If no DP specified, get all availible DP's in CM Env
if ($DistributionPoints -eq 0) {
    try {
        $DistributionPoints = @(Get-CMDistributionPoint -ErrorAction Stop).NetworkOSPath
    }
    catch {
        Write-Output "Could not get DistributionPoints: $($_.Exception.Message)"; Exit 1
    }
}

Set-Location -Path $env:SystemDrive

$TrimmedDPName = $DistributionPoints.trim("\")

#Set Params and run CleanupTool
foreach ($DP in $TrimmedDPName) {
    if ($DP -like "*DPServer*") {
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
