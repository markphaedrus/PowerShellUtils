Set-StrictMode -Version Latest
Function IsNullOrEmptyArray
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Position=0, Mandatory)][AllowNull()][AllowEmptyCollection()]
        $Object
    )
    (($null -eq $Object) -or ($Object.Count -eq 0))
}

Export-ModuleMember -Function IsNullOrEmptyArray

<#
 .Synopsis
  Checks to see that a file or directory exists.

 .Outputs
  If the file or directory exists, then outputs an empty string.
  If the file or directory does not exist, then outputs the path of the first element that does not exist.

  .Example
  ValidateFullPath c:\MyExistingDir\MyExistingSubdir\MyExistingFile.txt
  #Returns empty string
  .Example
  ValidateFullPath c:\MyExistingDir\MyExistingSubdir\MyNonExistingFile.txt
  #Returns c:\MyExistingDir\MyExistingSubdir\MyNonExistingFile.txt
  .Example
  ValidateFullPath c:\MyExistingDir\MyNonexistingSubdir\MyNonExistingFile.txt
  #Returns c:\MyExistingDir\MyNonexistingSubdir\
  .Example
  ValidateFullPath c:\MyNonexistingDir\MyNonexistingSubdir\MyNonExistingFile.txt
  #Returns c:\MyNonexistingDir\

#>

function ValidateFullPath
{
    [CmdletBinding(DefaultParameterSetName='DontThrow')]
    [OutputType([String])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #Pathname of the file or directory to validate.
        [String]$Path,
        #Type of object being validated ('Leaf' or 'Container')
        [Microsoft.PowerShell.Commands.TestPathType]$PathType="Any",
        #Throw an error if the path isn't valid.
        [Parameter(Mandatory,ParameterSetName="ThrowIfInvalid")]
        [Switch]$ThrowIfInvalid,
        #Description of path being tested, for example, "Source file for copy"; added to throw message
        [Parameter(Mandatory,ParameterSetName="ThrowIfInvalid")]
        [String]$ThrowDescription
    )

    if (Test-Path $Path -PathType:$PathType)
    {
        return ""
    }
    if (Test-Path $Path)
    {
        if ($ThrowIfInvalid)
        {
            throw "$ThrowDescription $Path is the wrong type"
        }
        return $Path
    }

    [String]$parent = Split-Path -Parent $Path
    if ([String]::IsNullOrEmpty($parent))
    {
        if ($ThrowIfInvalid)
        {
            throw "$ThrowDescription $Path does not exist; first missing part of path: $Path"
        }
        return $Path
    }

    [String]$firstInvalidPartOfParent = ValidateFullPath $parent -PathType Container
    [String]$firstInvalidPartOfCurrent = $firstInvalidPartOfParent
    if ([String]::IsNullOrEmpty($firstInvalidPartOfCurrent))
    {
        $firstInvalidPartOfCurrent = $Path
    }
    #Note that since we don't set ThrowIfInvalid in recursive calls, this throw will always happen at the top level
    if ($ThrowIfInvalid)
    {
        throw "$ThrowDescription $Path does not exist; first missing part of path: $firstInvalidPartOfCurrent"
    }
    return $firstInvalidPartOfCurrent
}

Export-ModuleMember -Function ValidateFullPath
