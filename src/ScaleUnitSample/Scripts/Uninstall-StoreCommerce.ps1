<#
.SYNOPSIS
Uninstalls the Store Commerce extension.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$workspaceFolder = $Env:common_workspaceFolder
$NewLine = [Environment]::NewLine

Write-Host
$InstallerPath = Join-Path $workspaceFolder "StoreCommerce\bin\Debug\net472\StoreCommerce.Installer.exe"
if (Test-Path -Path $InstallerPath) {
    Write-Host "Uninstalling the Store Commerce extension."
    & "$InstallerPath" uninstall
    if ($LastExitCode -ne 0) {
        Write-Host
        Write-CustomError "The Store Commerce extension uninstallation has failed with exit code $LastExitCode. Please examine the above logs to fix a problem and then try uninstalling again."
        Write-Host
        exit $LastExitCode
    }
}
else {
    Write-Host "The Store Commerce installer was not found at '$InstallerPath'."
}
