Set-StrictMode -Version Latest

<#
[String]$methodDefinition = @'
[DllImport("user32.dll")]
public extern static bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int width, int height, int flags);
'@

[String]$addTypeSplat = @{
    MemberDefinition = $methodDefinition
    Name = "Win32SetWindowPos"
    Namespace = 'Win32Functions'
    PassThru = $true
}

$SetWindowPosAsync = Add-Type @addTypeSplat
#>

function RunProcessAndWait {
    [OutputType([String])]
    param(
        [String]$ProcessName,
        [String[]]$ArgumentList,
        [Switch]$ThrowOnError,
        [Switch]$ReduceProcessPriority,
        [Switch]$CheckExitCode,
        [Switch]$DontFailOnErrorOutput,
        [Switch]$ReturnErrorOutput,
        [Int16]$SecondsBetweenPolls = 1,
        [System.Diagnostics.ProcessWindowStyle]$WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal,
        [Switch]$MoveProcessWindowToEdge,
        [Switch]$OutputProgress,
        [String]$ProgressProcessDescription,
        [Int]$ProgressShowDescriptionInterval = 20
    )
    [String]$standardOutputFile = ""
    [String]$standardErrorFile = ""
    [String]$standardOutput = ""
    [string]$standardError = ""
    try {
        Write-Debug "Executing process $ProcessName"
        $standardOutputFile = [System.IO.Path]::GetTempFileName()
        Write-Debug "Standard output file: $standardOutputFile"
        $standardErrorFile = [System.IO.Path]::GetTempFileName()
        Write-Debug "Standard error file: $standardErrorFile"

        [String]$lastDifferentOutputLine = ""
        Write-Debug "Starting process and retrieving process object"
        $Process = Start-Process -FilePath $ProcessName -ArgumentList $ArgumentList -RedirectStandardOutput $standardOutputFile -RedirectStandardError $standardErrorFile -PassThru -WindowStyle $WindowStyle
        if ($ReduceProcessPriority) {
            Write-Debug "Reducing process priority"
            try {
                Set-ProcessPriority -ProcessId $Process.id -Priority BelowNormal
            }
            catch {
                Write-Debug "Could not reduce process priority"
            }
        }
<#
        if ($MoveProcesssWindowToEdge)
        {
            Write-Debug "Moving process window to edge"
            try {
            }
            catch {
                Write-Debug "Could not move window"
            }
        }
#>
        Write-Debug "Waiting for process to exit"
        Start-Sleep $SecondsBetweenPolls
        [Int]$linesUntilShowDescription = 0
        While (-Not ($Process.HasExited)) {
            Write-Debug "Process still running"
            [String]$lastOutputLine = Get-Content $standardOutputFile -Tail 1
            if ($lastOutputLine -ne $lastDifferentOutputLine) {
                if ($OutputProgress)
                {
                    if (-not ([String]::IsNullOrWhiteSpace($ProgressProcessDescription))) {
                        if ($linesUntilShowDescription -le 0)
                        {
                            Write-Host $ProgressProcessDescription
                            $linesUntilShowDescription = $ProgressShowDescriptionInterval
                        }
                        else {
                            $linesUntilShowDescription = $linesUntilShowDescription - 1
                        }
                    }
                    Write-Host $lastOutputLine
                }
                else
                {
                    Write-Debug "Latest output: $lastOutputLine"
                }
                $lastDifferentOutputLine = $lastOutputLine
            }
            Start-Sleep -Seconds $SecondsBetweenPolls
        }
        Write-Debug "Process completed. Exit code: $($Process.ExitCode)."
        $standardOutput = Get-Content -Path $standardOutputFile -Raw
        $standardError = Get-Content -Path $standardErrorFile -Raw

        if ($CheckExitCode -and ($Process.ExitCode -ne 0)) {
            throw "Nonzero exit code."
        }
    }
    catch {
        $standardOutput = Get-Content -Path $standardOutputFile -Raw
        $standardError = Get-Content -Path $standardErrorFile -Raw
        [String]$errorOutput = "***Process $ProcessName failed.`r`n***Error output for process $ProcessName :`r`n$standardError`r`n***Standard output for process $ProcessName :`r`n$standardOutput`r`n***End of error output for process $ProcessName"        
        Write-Warning $errorOutput
        if ($ThrowOnError) {
            throw $errorOutput
        }
    }
    finally {
        if (-Not ([String]::IsNullOrEmpty($standardOutputFile))) {
            Remove-Item -Path $standardOutputFile
        }
        if (-Not ([String]::IsNullOrEmpty($standardErrorFile))) {
            Remove-Item -Path $standardErrorFile
        }
    }
    
    if (-not ([String]::IsNullOrWhiteSpace($standardError))) {
        if ($DontFailOnErrorOutput) {
            Write-Debug "Error ignored."
        }
        else {
            throw "Process $ProcessName returned error output."
        }
    }
    else {
        Write-Debug "Process succeeded."
    }
    Write-Debug "Returning."
    if ($ReturnErrorOutput) {
        return $standardError
    }
    else {
        return $standardOutput
    }
}

Export-ModuleMember -Function RunProcessAndWait