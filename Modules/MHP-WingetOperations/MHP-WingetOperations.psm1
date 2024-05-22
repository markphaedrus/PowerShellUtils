Set-StrictMode -Version Latest

Import-Module MHP-ListParsing
Import-Module MHP-ProcessOperations


function GetWingetList
{
    [CmdletBinding()]
    param(
        #Existing list to merge the new Winget operation's output with.
        #If this is not present, creates a fresh list.
        [Hashtable[]]$MergeWith
    )
    [String]$wingetOutput = RunWingetFunction @("list")

    [String]$wingetFilteredOutput = CleanWingetList -List $wingetOutput
    if ([String]::IsNullOrWhiteSpace($wingetFilteredOutput))
    {
        throw "All output from Winget was filtered. Output: $wingetOutput"
    }

    [Hashtable[]]$wingetList
    try
    {
        $wingetList = ParseSpaceDelimitedList -List $wingetFilteredOutput -MergeWith $MergeWith
    }
    catch
    {
        throw "Error occurred while parsing Winget list. List: $wingetOutput"
    }
    $wingetList
}

Export-ModuleMember -Function GetWingetList

function GetWingetAvailableUpgrades
{
    [CmdletBinding()]
    param(
        #Existing list to merge the new Winget operation's output with.
        #If this is not present, creates a fresh list.
        [Hashtable[]]$MergeWith
    )
    
    [String]$wingetOutput = RunWingetFunction @("upgrade")
    [String]$wingetFilteredOutput = CleanWingetList -List $wingetOutput
    [Hashtable[]]$wingetList = ParseSpaceDelimitedList -List $wingetFilteredOutput -MergeWith $MergeWith -ExcludeRegex 'upgrade(s) available.$'
    $wingetList
}

Export-ModuleMember -Function GetWingetAvailableUpgrades

function RunWingetFunction
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory)]
        [String[]]$ArgumentList
    )

    [String]$wingetOutput = RunProcessAndWait -ProcessName "winget.exe" -ArgumentList $ArgumentList
    if ([String]::IsNullOrWhiteSpace($wingetOutput))
    {
        throw "Winget returned no output."
    }
    return $wingetOutput
}

function CleanWingetList
{
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Position = 0, Mandatory)]
        [String]$List
    )
    [String[]]$listLines = $List -split [Environment]::NewLine
    [String[]]$filteredListLines = $listLines | Where-Object { (-not [String]::IsNullOrEmpty($_)) -and (-not ($_.ToString().StartsWith(' '))) }
    [String]$filteredList = $filteredListLines -join [Environment]::NewLine
    $filteredList
}