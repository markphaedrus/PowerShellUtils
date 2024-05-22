Set-StrictMode -Version Latest
<#
 .Synopsis
  Outputs a simple numbered dump of an object array, useful for debugging output.

 .Outputs
  String version of the object array.

 .Example
  Write-Information "My array is: $(GetObjectArrayDescription @('Hello', 23, $null, 45))"
  #Outputs:
  #My array is: 4 objects:
  #     0: Hello
  #     1: 23
  #     2: ($null)
  #     3: 45
 .Example
  Write-Information "My array is: $(GetObjectArrayDescription @())"
  #Outputs:
  #My array is: Empty array
 .Example
  Write-Information "My array is: $(GetObjectArrayDescription $null)"
  #Outputs:
  #My array is: Null array
#>
Function GetObjectArrayDescription
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Position=0, Mandatory, ValueFromPipeline)][AllowNull()][AllowEmptyCollection()]
        #Object array to dump. $null and empty arrays are allowed, and the array can contain null elements.
        [PSObject[]]$Array
    )
    process
    {
        if ($null -eq $Array)
        {
            $output = "Null array`r`n"
        }
        elseif ($Array.Count -eq 0)
        {
            $output = "Empty array`r`n"
        }
        else
        {
            $count = $Array.Count
            $obj = "objects"
            if ($count -eq 1)
            {
                $obj = "object"
            }
            $output = "$count ${obj}:`r`n"
            For($i = 0; $i -lt $count; $i++)
            {
                if ($null -eq $Array[$i])
                {
                    $element = '($null)'
                }
                else
                {
                    try 
                    {
                        $element = $Array[$i].ToString()
                    }
                    catch
                    {
                        $element = '(no available string representation)'
                    }
                }
                $thisline = "{0,6}: {1}`r`n" -f $i,$element
                $output = $output + $thisline
            }
        }
        $output
    }
}

Export-ModuleMember -Function GetObjectArrayDescription

