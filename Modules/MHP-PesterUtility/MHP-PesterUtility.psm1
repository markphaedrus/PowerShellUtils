function InitializePesterTest
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param(
        [Parameter(Position=0,Mandatory)]
        #Name of the module being tested -- for example, "MHP-Debugging"
        [String]$ModuleName
    )

    [String]$recovery = "You can probably recover by running InstallAndResetPester.ps1 as an administrator. If that doesn't work, check https://pester.dev/docs/introduction/installation for instructions."
    [PSModuleInfo]$pester = Get-Module -Name Pester
    if ($null -eq $pester)
    {
        Write-Output "Pester module not found. Refreshing the cache."
        Get-Module -Refresh -ListAvailable | Out-Null
        $pester = Get-Module -Name Pester
        if ($null -eq $pester)
        {
            throw "Pester module still not found on the system. $recovery"
        }
    }
    if (($pester.Version.Major -eq 3) -And ($pester.Version.Minor -eq 4))
    {
        throw "You're using the Pester version built into PowerShell. This test needs a newer one. $recovery "
    }
    if ($pester.Version -lt [System.Version]'5.0')
    {
        throw "You need to update Pester to version 5.0 or later. 'Update-Module -Name Pester' may do the trick. If that doesn't work: $recovery"
    }
    
    Write-Output 'Pester is up-to-date.'

    Get-Module -Name $ModuleName -All | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $ModuleName -Force -ErrorAction Stop

    Write-Output "Test module is successfully imported."

    return
}

Export-ModuleMember -Function InitializePesterTest

function GetTestCorpusDirectory
{
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Position=0,Mandatory)]
        # Name of module whose corpus directory should be retrieved
        [String]$ModuleName
    )

    try 
    {
        [String]$modulePath = (Get-Module -Name $ModuleName -All).Path
        [String]$moduleDir = Split-Path -Path $modulePath -Parent
        [String]$moduleCorpusDirectory = Join-Path -Path $moduleDir -ChildPath 'TestCorpus'
        return $moduleCorpusDirectory
    }
    catch
    {
        throw "Could not find module $ModuleName to retrieve its corpus directory"
    }
}

Export-ModuleMember -Function GetTestCorpusDirectory

function CreateTempDirectory
{
    [CmdletBinding()]
    [OutputType([String])]
    param()

    try
    {
        $dirPath = "$($env:Temp)/$([Guid]::NewGuid())" 
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        return $dirPath    
    }
    catch 
    {
        throw "Could not create temporary directory."    
    }
}

Export-ModuleMember -Function CreateTempDirectory

function DeleteTempDirectory
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param
    (
        [Parameter(Position=0,Mandatory)]
        # Path to temporary directory (returned by CreateTempDirectory)
        [String]$Path
    )
    
    try 
    {
        Remove-Item -Path $Path -Force -Recurse
    }
    catch {
        "Could not remove temporary directory $Path."        
    }
}

Export-ModuleMember -Function DeleteTempDirectory