$ToolPath = ""
$DistributionPoints = @(

)

if ($DistributionPoints -eq "") {
    try {
        $DistributionPoints = @(Get-CMDistributionPoint -ErrorAction Stop).NetworkOSPath
    }
    catch {
        Write-Output "Could not get DistributionPoints": $($_.Exception.Message); Exit 1
    }
}

$TrimedDPName = $DistributionPoints.Trim("\")

#Set Params and run CleanupTool
foreach ($DP in $TrimedDPName) {
    if ($DP -like "*DPServer*") {
        Write-Output "$DP found in exceptionlist, skipping..."
    }
    Else {
        $ContentLibCleanupTool = @{
            FilePath               = "$ToolPath\ContentLibraryCleanup.exe"
            ArgumentList           = @(
                "/DP $DP"
                "/Mode $Mode"
                "/q"
            )
            Wait                   = $true
            Passthru               = $true
            RedirectStandardOutput = "$ToolPath\Logs\$DP-LibraryCleanup.log"
        }
        try {
            Start-Process @ContentLibCleanupTool -ErrorAction Stop
        }
        catch {
            Write-Output "Could not start process: $($_.Exception.Message)"; Exit 1
        }
    }
