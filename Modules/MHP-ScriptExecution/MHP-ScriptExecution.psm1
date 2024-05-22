Set-StrictMode -Version Latest

<#
 .Synopsis
  Adds a Send To shortcut that runs a PowerShell script.

 .Description
  Creates a script shortcut in the user's SendTo folder. When the user right-clicks on a file or directory
  in File Explorer, the shortcut's name will appear in the Send To context menu. When the user chooses
  that menu option, the shortcut will execute and launch the script, passing in the file/directory's path
  as well as any other desired arguments.

 .Example
   # Adds an "Fix Things" option in the Send To menu, overwriting any existing option with that name.
   # When run, the shortcut will run the MyScript.ps1 script, passing in the selected file or directory in the -Path
   # argument, and with the MoreMagic switch set. The shortcut will then pause before exiting, letting the
   # user see the output in the command window.
   InstallSendToShortcut -ShortcutName "Fix Things" -SendToSourceObjectName "an archive file or a directory" -ScriptPath "C:\MyPath\MyScript.ps1" -ScriptArgumentList "-MoreMagic -Path %1" -HaveScriptPauseAfterExecution -Force
#>
function InstallSendToShortcut
{
    [CmdletBinding(PositionalBinding=$false,SupportsShouldProcess,ConfirmImpact='Low')]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory)]
        #The name that the shortcut should be given; this name is what the user will see in the context menu
        [String]$ShortcutName,

        [Parameter(Mandatory)]
        #The full pathname of the script that should be run by the shortcut.
        #You can set this to $script:MyInvocation.MyCommand.Path to have the shortcut call the script that's calling InstallSendToShortcut.
        [String]$ScriptPath,
        
        [Parameter(Mandatory)]
        #The arguments that should be passed to the script. The token %1 will be replaced with the selected file/directory's path.
        #Note that the shell will automatically put quote marks around a path containing spaces, so you should generally not surround the
        #%1 token with quote marks of your own.
        [String]$ScriptArgumentList,

        #If you set this switch, the shortcut script will echo the command that runs the PowerShell script before actually running that script.
        #This can be useful for debugging the shortcut.
        [Switch]$HaveScriptEchoLaunchCommand,
    
        #If you set this switch, the shortcut script will not close its command window until the user presses a key. This lets the user see
        #any output that the script may write.
        [Switch]$HaveScriptPauseAfterExecution,

        #If you set this switch, any existing Send To shortcut with the same name will be overwritten.
        [Switch]$Force
    )
    $scriptLaunchCommand = "powershell.exe -ExecutionPolicy Bypass ""$ScriptPath"" $ScriptArgumentList"
    Write-Verbose "Creating Send To option for $ShortcutName at $ScriptPath"

    $echo = ""
    if ($HaveScriptEchoLaunchCommand)
    {
        $echo = "echo $scriptLaunchCommand"
    }
    $pause = ""
    if ($HaveScriptPauseAfterExecution)
    {
        $pause = "pause"
    }
    
    $cmdScript = "@echo off`r`nREM Send To $ShortcutName`r`nREM Sends the selected File Explorer object to $ScriptPath`r`n`r`n$echo`r`ncall $scriptLaunchCommand`r`n$pause`r`n"

    $shortcutPath = "$env:appdata\Microsoft\Windows\SendTo\$ShortcutName.cmd"

    if (-Not ($Force))
    {
        if (Test-Path $shortcutPath)
        {
            throw "Send To shortcut $shortcutPath already exists"
        }
    }

    if($PSCmdlet.ShouldProcess($ShortcutName, "Create Send To option to run '$ScriptPath'"))
    {
        Out-File -InputObject $CmdScript -FilePath $shortcutPath -Encoding ascii -Force:$Force -Confirm:$false -WhatIf:$WhatIfPreference
        Write-Verbose "Shortcut created."
    }
}

Export-ModuleMember -Function InstallSendToShortcut 

<#
 .Synopsis
  Outputs the details of a scripting error.

 .Outputs
  The error message and stack trace of the error that occurred.
#>
function OutputError
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory, Position=0)]
        #The ErrorRecord object. In a 'catch' block, the ErrorRecord object is $_ .
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory)]
        #A description of the action that was being performed when the error occurred -- for example, "saving document".
        [String]$ActionDescription
    )
    "`r`n*** Error occurred while $ActionDescription ***"
    "*** Exception: ***"
    $ErrorRecord.Exception.Message
    "*** Error call stack: ***"
    $ErrorRecord.ScriptStackTrace
    "*** End of error output ***`r`n"
}

Export-ModuleMember -Function OutputError

<#
 .Synopsis
  Outputs the flags that should be passed to a PowerShell script being called, in order to capture the calling function's
  Verbose, Confirm, and WhatIf status as much as possible. In other words, pass in -Verbose if we're currently
  running in verbose mode, etc.

 .Outputs
  A string containing the flags that should be added to the script call.
#>
function GetCurrentCommonArgumentFlags
{
    [CmdletBinding()]
    [OutputType([String])]

    param (
        # Set this flag to include -Confirm and -WhatIf if appropriate
        [Switch]$IncludeShouldProcess
    )

    [String]$arguments = ""
    if ($VerbosePreference -ne 'SilentlyContinue')
    {
        $arguments += '-Verbose '
    }

    if ($IncludeShouldProcess)
    {
        if ($ConfirmPreference -ne 'High')
        {
            $arguments += '-Confirm '
        }
        if ($WhatIfPreference)
        {
            $arguments += '-WhatIf '
        }
    }
    $arguments.TrimEnd()
}

Export-ModuleMember -Function GetCurrentCommonArgumentFlags

<#
 .Synopsis
  Outputs the full path that should normally be used for a log file with a given name.

 .Outputs
  The full path that the log file should be written to.
#>
function GetDefaultLogPath
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Position=0,Mandatory)]
        #Name that should be given to the log file (for example, "MyScript.log"
        [String]$LogFileName
    )
    "$env:TEMP/$LogFileName"
}

Export-ModuleMember -Function GetDefaultLogPath


<#
 .Synopsis
  Replacement for Tee-Object. Writes input to a log file and to output.

 .Description
  A script often wants to log its output as well as displaying it. It's normal to use
  Tee-Object for this. But Tee-Object has a crucial problem: If the calling script
  has the -WhatIf flag set, Tee-Object does not work -- instead, it just displays a
  what-if message. And Tee-Object doesn't have a -WhatIf argument that you can set to
  $false. This effectively means that the calling script cannot use -WhatIf.

  LogAndOutput works around this problem by using Out-File, which does support
  suppressing -WhatIf.

 .Inputs
  Any pipeline data.

 .Outputs
  The same data passed to input.

  .Example
  "This is sample pipeline input" | LogAndOutput -FilePath "C:\MyLog.log"
  This has the same effect as
  "This is sample pipeline input" | Tee-Object -FilePath "C:\MyLog.log" -Append
  except that it properly ignores -WhatIf .
  #>

function LogAndOutput
{
    param (
        [Parameter(ValueFromPipeline)]$PipeData,
        [Parameter(Mandatory)][String]$LogFilePath
    )
    process
    {
        $PipeData | Out-File -FilePath $LogFilePath -Append -Confirm:$false -WhatIf:$false
        $PipeData
    }
}

Export-ModuleMember LogAndOutput

<#
 .Synopsis
  Initializes a log file.

 .Outputs
  The full path of the log file. This can be used as the FilePath for subsequent
  Write-* and Out-* statements.

  .Example
  #Create a "MyScript.log" log file in the default directory.
  #Run the 'DoMyThing' and 'DoMyOtherThing'function, and log various output streams to the log file.
  #If an error occurs, log a description as well.
    $log = StartLogging -LogFileName "MyScript.log" -ScriptName "MyScript"
    try 
    {
        &{
            $script:actionName = "Doing my first thing"
            DoMyThing
            $script:actionName = "Doing my other thing"
            DoMyOtherThing
        } 2>&1 3>&1 4>&1 6>&1 | LogAndOutput -LogFilePath $log 
    }
    catch 
    {
        OutputError -ErrorRecord $_ -ActionDescription $script:actionName | LogAndOutput -LogFilePath $log
    }
    finally
    {
        EndLogging -LogFilePath $log -ScriptName "OutputETLLogs"
    }
#>
function StartLogging
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        #The name of the script being executed.
        #This can be a filename or a human-readable description.
        [String]$ScriptName,

        [Parameter(Mandatory,ParameterSetName="ByPath")]
        #Full pathname of the log file that should be initialized.
        [String]$LogFilePath,

        [Parameter(Mandatory,ParameterSetName="ByName")]
        #Filename of the log file that should be initialized.
        #The log file will be created in the default logging directory.
        [String]$LogFileName,

        #Set this switch to append new logging output to the log file if it already exists.
        #If you don't set this switch, any previous content of the log file will be deleted.
        [Switch]$Append
    )
    if ($PSBoundParameters.ContainsKey("LogFilePath"))
    {
        $log = $LogFilePath
    }
    else
    {
        $log = GetDefaultLogPath -LogFileName $LogFileName
    }
    $divider = ""
    if ($Append)
    {
        $divider = "`r`n`r`n--------------------------------------------------`r`n`r`n"
    }
    $whatifwarning = ""
    if ($WhatIfPreference -eq $true)
    {
        $whatifwarning = "`r`n`r`n>>>>>>> WARNING: WhatIf mode is in effect -- WhatIf messages will not be included in log <<<<<<<`r`n`r`n"
    }
    $logStartMsg = $divider + "$ScriptName logging started at $(Get-Date)" + $whatifwarning

    Out-File -InputObject $logStartMsg -FilePath $log -Append:$Append -Confirm:$false -WhatIf:$false
    $log
}

Export-ModuleMember -Function StartLogging

<#
 .Synopsis
  Completes a log file.

 .Example
  See the StartLogging help for an example of the full logging flow.
#>
function EndLogging
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        #The name of the script being executed.
        #This can be a filename or a human-readable description.
        [String]$ScriptName,

        #Full pathname of the log file that should be initialized.
        #If you used the LogFileName argument in StartLogging, then
        #the output of StartLogging is the pathname that you should use here.
        [String]$LogFilePath
    )
    $logEndMsg = "$ScriptName logging ended at $(Get-Date)"
    Out-File -InputObject $logEndMsg -FilePath $LogFilePath -Append -Confirm:$false -WhatIf:$false
}

Export-ModuleMember -Function EndLogging