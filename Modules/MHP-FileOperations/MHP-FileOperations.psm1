Set-StrictMode -Version Latest

Import-Module MHP-ErrorChecking

<#
 .Synopsis
  Copies a file, with more error-checking than the standard Copy-Item command.
#>
function CopyFile
{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    [OutputType([System.Void])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #Pathname of the source file to be copied.
        [String]$Path,

        [Parameter(Mandatory,ParameterSetName="DestinationIsFullPath")]
        #Full pathname of the destination of the copy.
        #The file will be renamed if the filename in Path does not match the filename in DestinationFilePath.
        [String]$DestinationFilePath,

        [Parameter(Mandatory,ParameterSetName="DestinationIsDirectory")]
        #Full pathname of the destination of the copy.
        #The file will be not be renamed during the copy.
        [String]$DestinationDirectoryPath,

        #Set this switch to overwrite an existing file in the destination location
        [Switch]$Force
    )

    ValidateFullPath $Path -ThrowIfInvalid -ThrowDescription "Source file"| Out-Null

    if ($PSBoundParameters.ContainsKey("DestinationFilePath"))
    {
        $destinationDirectory = Split-Path $DestinationFilePath -Parent
        $destinationFileName = Split-Path $DestinationFilePath -Leaf
    }
    else
    {
        $destinationDirectory = $DestinationDirectoryPath
        $destinationFileName = Split-Path $Path -Leaf
    }

    ValidateFullPath $destinationDirectory -ThrowIfInvalid -ThrowDescription "Destination directory"| Out-Null

    $destinationFilePath = Join-Path -Path $destinationDirectory -ChildPath $destinationFileName
    If ((Test-Path -Path $destinationFilePath) -And (-Not $Force))
    {
        Throw "Destination file $destinationFilePath already exists"
    }

    if ($PSCmdlet.ShouldProcess($Path, "Copy to $destinationFilePath"))
    {
        try
        {
            Write-Verbose "Copying file $Path to $destinationFilePath"
            Copy-Item -Path $Path -Destination $destinationFilePath -Force:$Force -Confirm:$false -WhatIf:$WhatIfPreference
        }
        catch
        {
            Throw "Failure while copying $Path to $destinationFilePath"
        }
        If (-Not (Test-Path $destinationFilePath))
        {
            Throw "Source file $Path not copied successfully to $destinationFilePath"
        }
    }
}

Export-ModuleMember -Function CopyFile

<#
 .Synopsis
  Moves a file, with more error-checking than the standard Move-Item command.
#>
function MoveFile
{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    [OutputType([System.Void])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #Pathname of the source file to be moved.
        [String]$Path,

        [Parameter(Mandatory,ParameterSetName="DestinationIsFullPath")]
        #Full pathname of the destination of the move.
        #The file will be renamed if the filename in Path does not match the filename in DestinationFilePath.
        [String]$DestinationFilePath,

        [Parameter(Mandatory,ParameterSetName="DestinationIsDirectory")]
        #Full pathname of the destination of the move.
        #The file will be not be renamed during the move.
        [String]$DestinationDirectoryPath,

        #Set this switch to overwrite an existing file in the destination location
        [Switch]$Force
    )
    ValidateFullPath $Path -ThrowIfInvalid -ThrowDescription "Source file"| Out-Null

    if ($PSBoundParameters.ContainsKey("DestinationFilePath"))
    {
        $destinationDirectory = Split-Path $DestinationFilePath -Parent
        $destinationFileName = Split-Path $DestinationFilePath -Leaf
    }
    else
    {
        $destinationDirectory = $DestinationDirectoryPath
        $destinationFileName = Split-Path $Path -Leaf
    }

    ValidateFullPath $destinationDirectory -ThrowIfInvalid -ThrowDescription "Destination directory"| Out-Null
    
    $destinationFilePath = Join-Path -Path $destinationDirectory -ChildPath $destinationFileName
    If ((Test-Path -Path $destinationFilePath) -And (-Not $Force))
    {
        Throw "Destination file $destinationFilePath already exists"
    }

    if ($PSCmdlet.ShouldProcess($Path, "Move to $destinationFilePath"))
    {
        try
        {
            Write-Verbose "Moving file $Path to $destinationFilePath"
            Move-Item -Path $Path -Destination $destinationFilePath -Force:$Force -Confirm:$false -WhatIf:$WhatIfPreference
        }
        catch
        {
            Throw "Failure while moving $Path to $destinationFilePath"
        }
        If (-Not (Test-Path $destinationFilePath))
        {
            Throw "Source file $Path not moved successfully to $destinationFilePath"
        }
    }
}

Export-ModuleMember -Function MoveFile

<#
 .Synopsis
  Creates a directory, with more options than the standard New-Item command.
#>
function CreateDirectory
{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    [OutputType([System.Void])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #Pathname of the directory to create.
        [String]$Path,

        #Set this switch if you want to clear any existing contents of the directory if it already exists.
        [Switch]$ClearExistingContents,

        #Set this switch if you want to create any needed parent directories as well.
        [Switch]$CreateParentDirectoriesIfNeeded,

        #Set this switch to force overwriting existing files.
        [Switch]$Force
    )
    $parent = Split-Path -Parent $Path
    if (-Not (Test-Path $parent))
    {
        if ($CreateParentDirectoriesIfNeeded)
        {
            CreateDirectory -Path $parent -CreateParentDirectoriesIfNeeded -Force:$Force
        }
        else
        {
            throw "Parent directory $parent does not exist."
        }
    }

    if (Test-Path $Path)
    {
        if ($ClearExistingContents)
        {
            $existingContents = Get-ChildItem -Path $Path
            if (-Not (IsNullOrEmptyArray($existingContents)))
            {
                if ($PSCmdlet.ShouldProcess($Path, "Remove all existing contents"))
                {
                    try 
                    {
                        $existingContents | ForEach-Object -Process {
                            Remove-Item $_ -Recurse -Force:$Force -Confirm:$false -WhatIf:$WhatIfPreference | Out-Null
                            Write-Verbose "Existing contents of directory $Path removed."
                        }
                    }
                    catch
                    {
                        throw "Existing contents of $Path could not be removed."    
                    }
                }
            }
        }
    }
    else 
    {
        New-Item $Path -ItemType directory -Force:$Force | Out-Null        
    }

    if (($WhatIfPreference -ne $true) -And (-Not (Test-Path $Path)))
    {
        throw "Directory $Path could not be created."
    }
    Write-Debug "Directory $Path created."
}

Export-ModuleMember -Function CreateDirectory

<#
 .Synopsis
  Creates or updates a file, with more options than the standard New-Item command.
#>
function CreateFile
{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    [OutputType([System.Void])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #Pathname of the file to create.
        [String]$Path,

        #Set this switch if you want to clear any existing contents of the file if it already exists.
        [Switch]$ClearExistingContents,

        #Set this switch if you want to create any needed parent directories as well.
        [Switch]$CreateParentDirectoriesIfNeeded,

        #This string's contents are written to the file (either overwriting the existing contents or
        #appended to them, depending on the value of ClearExistingContents).
        [String]$NewContent,
        
        #Set this switch to force overwriting existing files.
        [Switch]$Force
    )

    $parent = Split-Path -Path $Path -Parent
    if (-Not (Test-Path -Path $parent -PathType Directory))
    {
        if ($CreateParentDirectoriesIfNeeded -And $PSCmdlet.ShouldProcess($parent, "Create parent directory for file $Path"))
        {
            CreateDirectory -Path $parent -CreateParentDirectoriesIfNeeded -Force:$Force -Confirm $false
        }
    }
    if (-Not (Test-Path -Path $parent -PathType Directory))
    {
        throw "Could not create parent directory $parent for file $Path"
    }

    if (-Not (Test-Path -Path $Path -PathType File))
    {
        if ($PSCmdlet.ShouldProcess($Path, "Create file"))
        {
            try 
            {
                New-Item -ItemType File -Path $Path -Confirm $false -Force:$Force`
            }
            catch {
                throw "Could not create file $Path."
            }    
        }
    }

    if ($ClearExistingContents)
    {
        $newContents = $NewContent ?? ""
        Set-Content -Path $Path -Value $newContents
    }
    elseif (-Not (IsNullOrEmpty($NewContent)))
    {
        Add-Content -Path $Path -Value $NewContents
    }
    Write-Debug "File $Path created."
}

Export-ModuleMember -Function CreateFile

<#
 .Synopsis
  Filters the files within a directory, and outputs those files whose filename (not pathname) matches the provided regular expression.

 .Outputs
  Array of file objects. Empty array if no files match the regular expression.

 .Example
  GetAllFilesMatchingExpression -Directory "C:\MyDir" -MatchExpression ".*\.[0-9]+\.etl"
  # outputs all files in C:\MyDir whose name ends with ".<some number>.etl"
#>
function GetAllFilesMatchingExpression
{
    [CmdletBinding()]
    [OutputType([System.IO.FileSystemInfo[]])]
    param (
        [Parameter(Mandatory)]
        #Directory to search
        [String]$Directory,

        [Parameter(Mandatory)]
        #Regular expression to match file names against
        [String]$MatchExpression
    )
    Write-Debug "GetAllFilesMatchingExpression: Directory: $Directory; Match expression: $MatchExpression"
    $folderFiles = Get-ChildItem -Path $Directory -File
    $folderMatchingFiles = $folderFiles | Where-Object { ($_.Name -match $MatchExpression) } | Sort-Object -Property Name
    if ($null -eq $folderMatchingFiles)
    {
        $folderMatchingFiles = @()
    }
    Write-Debug "GetAllFilesMatchingExpression returning files: $(GetObjectArrayDescription $folderMatchingFiles)"
    $folderMatchingFiles    
}

Export-ModuleMember -Function GetAllFilesMatchingExpression

