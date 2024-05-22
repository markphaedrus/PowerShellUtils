Set-StrictMode -Version Latest

Import-Module MHP-FileOperations
Import-Module MHP-ErrorChecking

Set-Variable -Name DefaultStoredStateFile -Option Constant -Value 'MHPStoredState.txt'

function GetStoredStateDirectory
{
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [string]$dir = Join-Path -Path $env:AppDataLocal -ChildPath "MHPPSLibraries"
    CreateDirectory -Path $dir
    return $dir
}

function GetStoredStateFilePath
{
    [CmdletBinding()]
    [OutputType([String])]
    param(
        # The name of the file to be used. 
        [String]$StateFileName = $DefaultStoredStateFile
    )

    $stateDir = GetStoredStateDirectory
    $stateFilePath = Join-Path -Path $stateDir -ChildPath $StateFileName
    return $stateFilePath
}

function GetStoredStateHashTable
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        #The name of the file to be used to store the hashtable.
        [String]$StateFileName = $DefaultStoredStateFile
    )

    [Hashtable]$table = @{}
    $stateFilePath = GetStoredStateFilePath -StateFileName $StateFileName
    if (Test-Path -Path $stateFilePath)
    {
        $jsonText = GetContent -Path $stateFilePath
        if (-Not (IsNullOrEmpty($jsonText)))
        {
            try {
                $table = ConvertFrom-Json -InputObject $jsonText -AsHashtable
            }
            catch {
                throw "Stored state file $stateFilePath could not be read"
            }
        }
    }
    return $table
}

function PutStoredStateHashTable
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory)]
        # The hashtable to store to disk.
        [Hashtable]$Table,

        #The name of the file to be used to store the hashtable.
        [String]$StateFileName = $DefaultStoredStateFile
    )

    [String]$jsonText
    try
    {
        $jsonText = ConvertTo-Json -InputObject $Table
    }
    catch {
        throw "Could not convert hash table to JSON."
    }

    [String]$StateFilePath = GetStoredStateFilePath -StateFileName $StateFileName

    try {
        CreateFile -Path $StateFilePath -CreateParentDirectoriesIfNeeded -ClearExistingContents -NewContent $jsonText
    }
    catch {
        throw "Could not update stored state hash table at $StateFilePath."
    }
}

function GetStoredStateValue
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        # Key for the stored state value to retrieve.
        [String]$Key,

        # Default value that should be used if the key is not present in the hashtable.
        # If omitted, an exception is thrown if the key is not present.
        [String]$DefaultValue,

        #The name of the file used to store the hashtable.
        [String]$StateFileName = $DefaultStoredStateFile
    )

    [Hashtable]$storedState = GetStoredStateHashTable -StateFileName $StateFileName
    if ($storedState.ContainsKey($Key))
    {
        return ToString($storedState[$Key])
    }
    elseif ($DefaultValue)
    {
        return $DefaultValue
    }
    else
    {
        throw "Key $Key not present in stored state."
    }
}

Export-ModuleMember -Function GetStoredStateValue

function DoesStoredStateValueExist
{
    [CmdletBinding()]
    [OutputType([Bool])]
    param (
        [Parameter(Mandatory)]
        # Key for the stored state value to retrieve.
        [String]$Key,

        #The name of the file used to store the hashtable.
        [String]$StateFileName = $DefaultStoredStateFile
    )

    [Hashtable]$storedState = GetStoredStateHashTable -StateFileName $StateFileName
    return $storedState.ContainsKey($Key)
}

Export-ModuleMember -Function DoesStoredStateValueExist


function PutStoredStateValue
{
    [CmdletBinding()]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory)]
        # Key for the stored state value to set.
        [String]$Key,

        [Parameter(Mandatory)]
        # Value to set for the specified key.
        [String]$Value,

        #The name of the file used to store the hashtable.
        [String]$StateFileName = $DefaultStoredStateFile
    )

    [Hashtable]$storedState = GetStoredStateHashTable -StateFileName $StateFileName
    $storedState[$Key] = ToString($Value)
    PutStoredStateHashTable -Table $storedState -StateFileName $StateFileName
}

Export-ModuleMember -Function PutStoredStateValue