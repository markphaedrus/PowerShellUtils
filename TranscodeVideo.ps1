[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)][String]$SourcePath,
    [String]$HandbrakeCliPath = "C:\Program Files\Handbrake\Handbrakecli.exe",
    [String]$TranscodedFileDir = "",
    [String]$MoveSourceFileToDir = "",
    [Switch]$DontMoveSourceFile,
    [Switch]$Recurse
)

Set-StrictMode -Version Latest
$Error.Clear()
$InformationPreference = "Continue"

Import-Module ".\Modules\MHP-ErrorChecking" -Force
Import-Module ".\Modules\MHP-FileOperations" -Force
Import-Module ".\Modules\MHP-ProcessOperations" -Force

function IsFileTranscodable(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)][String]$Path
) {
    Write-Host "Checking transcodability for $Path"
    [String]$fileName = Split-Path -Path $Path -Leaf
    if ($fileName -ilike "*- bluray.mkv") {
        return $true
    }
<#    elseif ($fileName -ilike "*- uhd.mkv") {
        return $true
    }
#>
    elseif ($fileName -ilike "*- dvd.mkv") {
        return $true
    }
    return $false
}
function GetDestinationFileName(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [String]$SourceFullPath
) {
    [String]$fileName = (Split-Path -Path $SourceFullPath -Leaf).Trim()
    if ($fileName -ilike "*- bluray.mkv") {
        return $fileName.Substring(0, $fileName.Length - 10) + "H264CQ22.mkv"
    }
<#    elseif ($fileName -ilike "*- uhd.mkv") {
        return $fileName.Substring(0, $fileName.Length - 7) + "AV1CQ23.mkv"
    }
#>
    elseif ($fileName -ilike "*- dvd.mkv") {
        return $fileName.SubString(0, $fileName.Length - 7) + "H264CQ18.mkv"
    }
    else {
        throw "Unknown extension"
    }
}

function GetHandbrakePreset(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [String]$SourceFullPath
) {
    [String]$fileName = (Split-Path -Path $SourceFullPath -Leaf).Trim()
    if ($fileName -ilike "*- bluray.mkv") {
        return "H.264 - Source res and frame rate - CQ22"
    }
<#    elseif ($fileName -ilike "*- uhd.mkv") {
        return "AV1 - Source res and frame rate - CQ23"
    }
#>
    elseif ($fileName -ilike "*- dvd.mkv") {
        return "H.264 - Source res and frame rate - CQ18"
    }
    else {
        throw "Unknown extension"
    }
}

function GetDestinationDirectory(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [String]$SourceFullPath
) {
    if (Test-Path -Path $SourceFullPath -PathType Leaf) {
        return Split-Path -Path $SourceFullPath -Parent
    } elseif (Test-Path -Path $SourceFullPath -PathType Container) {
        return $SourceFullPath
    } else {
        throw "Cannot calculate destination directory for nonexistent source file $SourceFullPath"
    }
}

function GetOriginalFileDestinationDirectory(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)][String]$SourceFullPath
) {
    [String]$sourceDir = Split-Path -Path $SourceFullPath -Parent
    [String]$drivePrefix = Split-Path $SourceFullPath -Qualifier
    [String]$sourcePathWithoutDrive = $sourceDir.Substring($drivePrefix.Length, $sourceDir.Length - $drivePrefix.Length)
    [String]$finalDir = Join-Path -Path $drivePrefix -ChildPath "\Originals\"
    $finalDir = Join-Path -Path  $finalDir -ChildPath $sourcePathWithoutDrive
    return $finalDir
}

function GetDestinationTempFileFullPath(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [String]$DestinationFullPath
) {
    [String]$drivePrefix = Split-Path $DestinationFullPath -Qualifier
    [String]$tempDir = Join-Path -Path $drivePrefix -ChildPath "\HandbrakeTemp\"
    CreateDirectory -Path $tempDir
    [String]$filename = Split-Path $DestinationFullPath -Leaf
    [String]$tempFullPath = Join-Path -Path $tempDir -ChildPath $filename
    return $tempFullPath
}

function TranscodeFile(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [String]$SourceFullPath,
    [Parameter(Mandatory=$true)] [String]$TranscodedDestinationDirPath
) {

    [String]$transcodedDestinationFilename = GetDestinationFileName($SourceFullPath)
    [String]$transcodedDestinationFullPath = Join-Path -Path $TranscodedDestinationDirPath -ChildPath $transcodedDestinationFilename
    if (Test-Path -Path $transcodedDestinationFullPath) {
        throw "Transcode destination file $transcodedDestinationFullPath already exists"
    }

    Write-Host "File being transcoded: $SourceFullPath"
    Write-Host "Transcode destination file: $transcodedDestinationFullPath"
    CreateDirectory -Path $transcodedDestinationDirPath -CreateParentDirectoriesIfNeeded

    [String]$transcodedDestinationTempFullPath = GetDestinationTempFileFullPath($transcodedDestinationFullPath)
    Write-Host "Will transcode into temporary location: $transcodedDestinationTempFullPath"

    [String]$originalDestinationDirPath = ""

    if ($DontMoveSourceFile) {
        Write-Host "Source file will not be moved."
    }
    else {
        $originalDestinationDirPath = $MoveSourceFileToDir
        if ([String]::IsNullOrEmpty($originalDestinationDirPath)) {
            $originalDestinationDirPath = GetOriginalFileDestinationDirectory($SourceFullPath)
        
        }
        Write-Host "File being transcoded will be moved to: $originalDestinationDirPath"
        CreateDirectory -Path $originalDestinationDirPath -CreateParentDirectoriesIfNeeded
    }

    [String]$handbrakePreset = GetHandbrakePreset($SourceFullPath)

    Write-Host "Handbrake preset: $handbrakePreset"


    [String[]]$handbrakeArgumentList = "--preset-import-gui", "--preset", "`"$handbrakePreset`"", "-i", "`"$SourceFullPath`"", "-o", "`"$transcodedDestinationTempFullPath`""

    Write-Host "Starting Handbrake..."

    [String]$processDescription = "Transcoding $SourceFullPath to $transcodedDestinationTempFullPath"
    [String]$handbrakeOutput = RunProcessAndWait -ProcessName $HandbrakeCliPath -ArgumentList $handbrakeArgumentList -CheckExitCode -DontFailOnErrorOutput -ReturnErrorOutput -ReduceProcessPriority -SecondsBetweenPolls 10 -WindowStyle Normal -MoveProcessWindowToEdge -OutputProgress -ProgressProcessDescription $processDescription

    [Boolean]$handbrakeSucceeded = (0 -le $handbrakeOutput.IndexOf("libhb: work result = 0"))

    if (-not $handbrakeSucceeded) {
        throw "Handbrake failed"
    }
    if (-not (Test-Path -Path $transcodedDestinationTempFullPath)) {
        throw "Handbrake did not create file as expected: $transcodedDestinationFullPath"
    }

    Write-Host "Success!"

    Write-Host "Moving transcoded file to $transcodedDestinationFullPath"
    MoveFile -Path $transcodedDestinationTempFullPath -DestinationFilePath $transcodedDestinationFullPath

    if (-not $DontMoveSourceFile) {
        Write-Host "Moving original file to $originalDestinationDirPath"

        MoveFile -Path $SourceFullPath -DestinationDirectoryPath $originalDestinationDirPath 
    }

    Write-Host "Done transcoding $SourceFullPath"
}

function TranscodeDirectory(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [String]$SourceDirPath,
    [Parameter(Mandatory=$true)] [String]$TranscodedDestinationDirPath,
    [Parameter(Mandatory=$true)] [Boolean]$Recurse
) {
    Write-Host "Transcoding directory $SourceDirPath"
    Write-Host "Destination for transcoded files is $TranscodedDestinationDirPath"
    $filesInDir = Get-ChildItem -Path $SourceDirPath | Where-Object { $_.PSIsContainer -eq $false } 
    foreach ($file in $filesInDir) {
        [String]$filePath = $file.FullName
        Write-Host "Found file $filePath"
        if (IsFileTranscodable($filePath)) {
            Write-Host "Found transcodable file $filePath"
            TranscodeFile -SourceFullPath $filePath -TranscodedDestinationDirPath $TranscodedDestinationDirPath
        }
        else {
            Write-Host "Found non-transcodable file $filePath"
        }
    }
    if ($Recurse)
    {
        $dirsInDir = Get-ChildItem -Path $SourceDirPath | Where-Object {$_.PSIsContainer -eq $true}
        foreach ($dir in $dirsInDir) {
            [String]$dirPath = $dir.FullName
            [String]$dirName = $dir.Name
            [String]$newTranscodedFileDirPath = Join-Path -Path $TranscodedDestinationDirPath -ChildPath $dirName
            Write-Host "Recursing into subdirectory $dirPath"
            Write-Host "New destination for transcoded files is $newTranscodedFileDirPath"
            TranscodeDirectory -SourceDirPath $dirPath -TranscodedDestinationDirPath $newTranscodedFileDirPath -Recurse $true
        }
    }
}
ValidateFullPath -Path $SourcePath -ThrowIfInvalid -ThrowDescription "SourcePath parameter"
ValidateFullPath -Path $HandbrakeCliPath -PathType Leaf -ThrowIfInvalid -ThrowDescription "HandbrakeCliPath parameter"

[String]$transcodedDestinationDirPath = $TranscodedFileDir
if ([String]::IsNullOrEmpty($transcodedDestinationDirPath)) {
    $transcodedDestinationDirPath = GetDestinationDirectory($SourcePath)
}

if (Test-Path -Path $SourcePath -PathType Leaf) {
    TranscodeFile -SourceFullPath $SourcePath -TranscodedDestinationDirPath $transcodedDestinationDirPath
}
elseif (Test-Path -Path $SourcePath -PathType Container) {
    TranscodeDirectory -SourceDirPath $SourcePath -TranscodedDestinationDirPath $transcodedDestinationDirPath -Recurse $Recurse.ToBool()
}
else {
    throw "Source file not found or unexpected type: $SourcePath"
}