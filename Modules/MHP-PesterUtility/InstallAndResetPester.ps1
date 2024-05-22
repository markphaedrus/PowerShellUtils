Set-StrictMode -Version Latest
$Error.Clear()
$InformationPreference = "Continue"

[String]$recovery = "You may need to rerun this script as administrator. If that doesn't work, see https://pester.dev/docs/introduction/installation ."

function RemoveBuiltInPesterIfNeeded
{
    $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
    if (Test-Path -Path $module)
    {
        try {
            takeown /F $module /A /R
            icacls $module /reset
            icacls $module /grant "*S-1-5-32-544:F" /inheritance:d /T
            Remove-Item -Path $module -Recurse -Force -Confirm:$false                        
        }
        catch {
            throw "PowerShell's built-in version of Pester exists and cannot be removed. $recovery"
        }
        throw "PowerShell's built-in version of Pester has now been removed. However, it may still be cached in current PowerShell sessions. You should restart your computer and then run this script again."
    }
}

function RemoveCurrentPesterIfNeeded
{
    $pester = Get-Module Pester
    if ($null -ne $pester)
    {
        try {
            Remove-Module -Name Pester -Force
            Write-Output "Current version of Pester removed."                
        }
        catch {
            throw "Existing version of Pester could not be removed. $recovery"
        }
    }
    else {
        Write-Output "Pester does not seem to be installed. Skipping removal."
    }
}

function InstallPester
{
    try {
        Install-Module -Name Pester -Force
    }
    catch {
        throw "Pester could not be installed. $recovery"
    }

    Get-Module -ListAvailable -Refresh
    Import-Module -Name Pester -Force
    $pester = Get-Module -Name Pester
    if ($null -eq $pester)
    {
        throw "Pester installation failed. $recovery"
    }
    if ($pester.Version -lt [System.Version]'5.0.0')
    {
        throw "Pester version installed is not current enough. $recovery"
    }
}

RemoveBuiltInPesterIfNeeded
RemoveCurrentPesterIfNeeded
InstallPester
Write-Output "Pester has been reset and installed. But some PowerShell windows may still have the old version of Pester cached."
Write-Output "You should restart your computer before running Pester tests."