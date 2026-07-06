<#
.SYNOPSIS
Installs the Store Commerce extension.
#>
Import-Module (Join-Path $PSScriptRoot "ErrorDecorator.psm1")

$workspaceFolder = $Env:common_workspaceFolder
$NewLine = [Environment]::NewLine

Write-Host
Write-Host "Installing the Store Commerce extension."
$InstallerPath = Join-Path $workspaceFolder "StoreCommerce\bin\Debug\net472\StoreCommerce.Installer.exe"

if (-not (Test-Path -Path $InstallerPath)) {
    Write-CustomError "The Store Commerce installer was not found at '$InstallerPath'. Please build the solution first."
    Write-Host
    exit 1
}

& "$InstallerPath" install

if ($LastExitCode -ne 0) {
    Write-Host
    Write-CustomError "The Store Commerce extension installation has failed with exit code $LastExitCode. Please examine the above logs to fix a problem and start again."
    Write-Host
    exit $LastExitCode
}

Write-Host
Write-Host "Store Commerce extension installed successfully."
Write-Host "Restart the Store Commerce application for the changes to take effect."
