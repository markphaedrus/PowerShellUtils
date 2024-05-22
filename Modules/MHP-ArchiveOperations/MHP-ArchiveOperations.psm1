Set-StrictMode -Version Latest

Import-Module MHP-ErrorChecking

<#
 .Synopsis
  Determines whether a file can be unpacked by UnpackArchiveFile.

  .Outputs
  True if the specified file is a ZIP or CAB archive

 .Description
#>
function IsFileUnpackableArchive
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Position=0,Mandatory)]
        #Filename or pathname of file to check
        [String]$File
    )
    $fileName = Split-Path -Leaf $File
    $isCAB = $fileName.TrimEnd().ToLower().EndsWith(".cab")
    $isZIP = $fileName.TrimEnd().ToLower().EndsWith(".zip")
    ($isCAB -Or $isZIP)
}

Export-ModuleMember -Function IsFileUnpackableArchive

<#
 .Synopsis
  Unpacks the contents of a ZIP or CAB archive to a specified directory.
#>
function UnpackArchiveFile
{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium',DefaultParameterSetName="DontCreateUnpackDirectory")]
    [OutputType([System.Void])]
    param (
        [Parameter(Position=0,Mandatory)]
        #Pathname of file to unpack
        [String]$File,

        [Parameter(Mandatory)]
        #Pathname of directory to unpack the archive's files into.
        [String]$UnpackDirectoryPath,

        [Parameter(Mandatory, ParameterSetName="CreateUnpackDirectory")]
        #Set this switch to create the unpack directory if it does not already exist.
        [Switch]$CreateUnpackDirectoryIfNeeded,

        [Parameter(ParameterSetName="CreateUnpackDirectory")]
        #Set this switch to also create the unpack directory's parent directories if needed.
        [Switch]$CreateUnpackParentDirectoryIfNeeded,

        #Set this switch to delete any existing contents of the unpack directory
        [Switch]$ClearExistingContents,

        #Set this switch to force file operations
        [Switch]$Force
    )

    ValidateFullPath $File -PathType Leaf -ThrowIfInvalid -ThrowDescription "Archive file" | Out-Null

    $fileName = Split-Path -Leaf $File
    $isCAB = $fileName.TrimEnd().ToLower().EndsWith(".cab")
    $isZIP = $fileName.TrimEnd().ToLower().EndsWith(".zip")
    if (-Not ($isCAB -or $isZIP))
    {
        Throw "$File is a non-archive file."
    }
    if ($CreateUnpackDirectoryIfNeeded.IsPresent -or $ClearExistingContents.IsPresent)
    {
        CreateDirectory -Path $UnpackDirectoryPath -CreateParentDirectoriesIfNeeded:$CreateUnpackParentDirectoryIfNeeded -ClearExistingContents:$ClearExistingContents -Force:$Force 
    }

    if ($isCAB)
    {
        if ($PSCmdlet.ShouldProcess($File, "Expand CAB file to $UnpackDirectoryPath"))
        {
            $expandArgs = @($File, "-F:*", $UnpackDirectoryPath)
            Write-Verbose "Expanding CAB file $File to $UnpackDirectoryPath with arguments $expandArgs"
            if ($WhatIfPreference -eq $false)
            {
                & expand $expandArgs | Write-Verbose
            }
        }
    }
    else
    {
        if ($PSCmdlet.ShouldProcess($File, "Expand ZIP file to $UnpackDirectoryPath"))
        {
            Write-Verbose "Expanding ZIP file $File to $UnpackDirectoryPath"
            if ($WhatIfPreference -eq $false)
            {
                [System.IO.Compression.ZipFile]::ExtractToDirectory($File, $UnpackDirectoryPath)
#                Expand-Archive -Path $File -DestinationPath $UnpackDirectoryPath -Force -Confirm:$false -WhatIf:$false| Write-Output
            }
        }
    }
}

Export-ModuleMember -Function UnpackArchiveFile
