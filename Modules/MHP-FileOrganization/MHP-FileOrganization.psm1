Set-StrictMode -Version Latest

Import-Module MHP-FileOperations
Import-Module MHP-Debugging

<#
 .Synopsis
  Strips all extensions from the provided file name(s).

 .Outputs
  The filename without extensions.

 .Example
  GetFileNameWithoutAllExtensions "MyBaseName.123.abc.txt"
  # returns "MyBaseName"
#>
function GetFileNameWithoutAllExtensions
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        #Filename to remove extensions from
        [String]$Filenames
    )
    process
    {
        $Filenames | ForEach-Object -Process {
            $currentFileName = $_
            $strippedFileName = $_
            $found = $false
            for ($i = 1; $i -le 10; $i++)
            {
                $strippedFileName = [System.IO.Path]::GetFileNameWithoutExtension($currentFileName)
                If ($strippedFileName -eq $currentFileName)
                {
                    $found = $true
                    break
                }
                $currentFileName = $strippedFileName
            }
            if ($found)
            {
                Write-Debug "GetFileNameWithoutAllExtensions stripped $_ to $strippedFileName"
                $strippedFileName
            }
            else
            {
                Throw "$_ has too many extensions"                    
            }
        }
    }
}

Export-ModuleMember -Function GetFileNameWithoutAllExtensions

<#
.Synopsis
Moves files into subdirectories named after the base name of the files.

.Outputs
String array containing the filenames (not pathnames) of the subdirectories that were used.

.Description
Accepts an array, which can contain file objects or file names or file paths, and a target directory.
Moves the files into subdirectories of the target directory, where each subdirectory has a name matching
the base name of the file (the file name without any extensions). 
For example, "MyFile.001.txt" and "MyFile.doc" would both be moved into a "MyFile" subdirectory.

.Example
Suppose the C:\SortMe directory contains these files (and no subdirectories):
- LogFile.001.txt
- LogFile.047.txt
- TextFile.1.txt
- TextFile.2.txt
- MyOtherFile.txt
This code:
$files = Get-ChildItem -Path "C:\SortMe" -File
MoveFilesIntoSubdirectories -Files $files -Directory "C:\SortMe" -FilesAreFullPaths -CreateSubdirectories
Will rearrange C:\SortMe to have the following hierarchy:
- LogFile
-    LogFile.001.txt
-    LogFile.047.txt
- TextFile
-    TextFile.1.txt
-    TextFile.2.txt
- MyOtherFile
-   MyOtherFile.txt
#>

function MoveFilesIntoSubdirectories
{
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    [OutputType([String[]])]
    param (
        [Parameter(Position = 0, ValueFromPipeline, Mandatory)]
        #Array of file objects or file names or file paths of files that should be moved.
        #(If only file names are provided, the files must be in the directory specified by Directory.)
        [String[]]$Files,

        [Parameter(Mandatory)]
        #Directory that the subdirectories and files will be placed in.
        [String]$Directory,

        #If this switch is set, Files must be an array of file objects or file paths.
        #Otherwise, Files must be an array of filenames.
        [Switch]$FilesAreFullPaths,

        #If this switch is set, the needed subdirectories will be created in Directory.
        #Otherwise, the subdirectories must already exist.
        [Switch]$CreateSubdirectories
    )
    Begin
    {
        Write-Verbose "Moving files into subdirectories of directory $Directory"
        $subdirectoriesused = @()
    }
    Process
    {
        $Files | ForEach-Object -Process {
            $sourceFileNameOrPath = $_
            $sourceFileBaseName = GetFileNameWithoutAllExtensions -FileName $sourceFileNameOrPath
            if ($FilesAreFullPaths)
            {
                $sourceFilePath = $sourceFileNameOrPath
            }
            Else
            {
                $sourceFilePath = "$Directory/$sourceFileNameOrPath"
            }
            ValidateFullPath $sourceFilePath -PathType Leaf| Out-Null
            $destinationDirPath = "$Directory/$sourceFileBaseName"
            $subdirectoriesused += $sourceFileBaseName
            if ($PSCmdlet.ShouldProcess($sourceFilePath, "Move to $destinationDirPath"))
            {
                if ($WhatIfPreference -ne $true)
                {
                    $missingParentDirectory = ValidateFullPath $destinationDirPath -PathType Container
                    if (-Not ([String]::IsNullOrEmpty($missingParentDirectory)))
                    {
                        If ($CreateSubdirectories)
                        {
                            CreateDirectory -Path $destinationDirPath -Confirm:$false -WhatIf:$false
                            Write-Verbose "Created subdirectory $destinationDirPath"
                        }
                        Else
                        {
                            Throw "Subdirectory $destinationDirPath does not exist. First missing element is $missingParentDirectory."
                        }
                    }
                    MoveFile -Source $sourceFilePath -Destination $destinationDirPath -DestinationIsDirectory -Confirm:$false -WhatIf:$false | Out-Null
                }
            }
        }
    }
    End
    {
        Write-Verbose "Completed moving files into subdirectories"
        $subdirectoriesused | Sort-Object -Unique | Write-Output
    }
}

Export-ModuleMember -Function MoveFilesIntoSubdirectories

<#
.Synopsis
Sorts the files in a directory, moving files whose names match a regular expression
into subdirectories named after the base name of the files.

.Description
Searches the specified directory for all files whose filenames match the regular expression.
Moves each matching file into a subdirectory whose name matches the base name of the file
(the filename without any extensions).

.Outputs
String array containing the filenames (not pathnames) of the subdirectories that were used.

.Example
Suppose the C:\SortMe directory contains these files (and no subdirectories):
- LogFile.001.txt
- LogFile.047.txt
- TextFile.1.txt
- TextFile.2.txt
  UnnumberedLog.txt
- MyNotes.001.txt
This code:
OrganizeMatchingFilesIntoSubdirectories -Directory "C:\SortMe" -MatchExpression ".*\.[0-9]+\.txt" -CreateSubdirectories
Will rearrange C:\SortMe to have the following hierarchy:
- LogFile (newly-created subdirectory)
-    LogFile.001.txt
-    LogFile.047.txt
- TextFile (newly-created subdirectory)
-    TextFile.1.txt
-    TextFile.2.txt
- UnnumberedLog.txt
- MyNotes.001.txt
#>
function OrganizeMatchingFilesIntoSubdirectories
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([String[]])]
    param (
        [Parameter(Mandatory)]
        #The full path of the directory whose files should be organized.
        [String]$Directory,

        [Parameter(Mandatory)]
        #The script block that should be used to identify the files that should be moved. 
        #The script block will receive a single unnamed parameter: the file object to be tested.
        #The script block should output $true if the file matches.
        #The regular expression that should be used to identify the files to be sorted.
        [String]$MatchExpression
    )
    Write-Debug "OrganizeMatchingFilesIntoSubdirectories: Directory: $Directory; MatchExpression: $MatchExpression"
    $files = GetAllFilesMatchingExpression -Directory $Directory -MatchExpression $MatchExpression
    if (($null -eq $files) -or ($files.Count -eq 0))
    {
        Write-Debug "No matching files were found to organize."
    }
    else
    {
        MoveFilesIntoSubdirectories -Files $files -Directory $Directory -CreateSubdirectories -FilesAreFullPaths | Write-Output
    }
    Write-Debug "OrganizeMatchingFilesIntoSubdirectories complete."
}

Export-ModuleMember -Function OrganizeMatchingFilesIntoSubdirectories

function MoveFilesIntoMatchingSubdirectories
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileSystemInfo[]])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        #The file objects to be organized.
        [System.IO.FileSystemInfo[]]$Files,

        [Parameter(Mandatory)]
        #The destination directory. Files will be moved to subdirectories within this directory.
        [String]$DestinationBasePath,

        [Parameter(Mandatory)]
        #The script block that should be used to identify the subdirectory that should be used for each file. 
        #The script block will receive a single unnamed parameter: the file object to be tested.
        #The script block should output a filename (not a pathname) of the subdirectory to be used.
        #If the script block outputs $null or an empty string, the file is not moved.
        [ScriptBlock]$MatchExpression
    )
    Write-Debug "OrganizeMatchingFilesIntoSubdirectories: Directory: $Directory; MatchExpression: $MatchExpression"
    $files = GetAllFilesMatchingExpression -Directory $Directory -MatchExpression $MatchExpression
    if (($null -eq $files) -or ($files.Count -eq 0))
    {
        Write-Debug "No matching files were found to organize."
    }
    else
    {
        MoveFilesIntoSubdirectories -Files $files -Directory $Directory -CreateSubdirectories -FilesAreFullPaths | Write-Output
    }
    Write-Debug "OrganizeMatchingFilesIntoSubdirectories complete."
}
