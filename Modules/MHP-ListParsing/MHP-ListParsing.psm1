Set-StrictMode -Version Latest

<#
 .Synopsis
  Converts a text list into an array of PowerShell objects.
  Currently expects a list in the following format:

  Name                                Id                             Version                     Source
  --------------------------------------------------------------------------------------------------------------
  HP Desktop Support Utilities        AD2F1837                       7.0.6.0                         
  Microsoft Edge                      Microsoft.Edge                 96.0.1054.62                winget

  Details of the currently-expected format:
  * Lists delimited by tabs, commas, etc. are not currently supported.
  * The first line of the list is considered to be headers. Headers are strings separated by two or more spaces.
  * After the first line:
    * Dashed lines are ignored.
    * All other lines are considered to be data rows, with fields lined up with the positions of the headers.
    * Trailing blanks are ignored.
  The example list above would be parsed into the following array of objects:
  [
      {
          "Name": "HP Desktop Support Utilities",
          "Id": "AD2F1837",
          "Version": "7.0.6.0"
      },
      {
          "Name": "Microsoft Edge",
          "Id": "Microsoft.Edge",
          "Version": "96.0.1054.62",
          "Source": "winget"
      }
  ]

  #>

function ParseSpaceDelimitedList
{
    [CmdletBinding()]
    [OutputType([Hashtable[]])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #List to be parsed.
        [String]$List,

        # Regular expression. Lines matching this expression will be excluded from the list.
        [String]$ExcludeRegex,

        [Parameter()][AllowNull()][AllowEmptyCollection()]
        #Existing list, if any, to merge the new list's contents into.
        [System.Collections.Generic.List[Hashtable]]$MergeWith

    )

    $items = $MergeWith ?? [System.Collections.Generic.List[Hashtable]]::new()
    [ColumnInfo[]]$columns = @()
    [String[]]$listLines = $List.Split([Environment]::NewLine)
    if ($listLines.Count -lt 2)
    {
        throw "List too short"
    }
    foreach ($listLine in $listLines)
    {
        if ([String]::IsNullOrWhiteSpace($listLine))
        {
            continue
        }
        elseif ($listLine -match '^-*$')
        {
            continue
        }
        elseif ((-Not ([String]::IsNullOrWhiteSpace($ExcludeRegex))) -And ($listLine -match $ExcludeRegex))
        {
            continue
        }
        elseif ($columns.Count -eq 0)
        {
            $columns = ParseSpaceDelimitedHeaderLine($listLine)
            if (($null -eq $columns) -or ($columns.Count -eq 0))
            {
                throw "List has no parsable headers"
            }
        }
        else
        {
            $item = @{}
            foreach ($column in $columns)
            {
                [int32]$fieldLength = $listLine.Length - $column.StartingIndex
                if ($fieldLength -gt $column.Length)
                {
                    $fieldLength = $column.Length
                }
                if ($fieldLength -gt 0)
                {
                    [String]$columndata = $listLine.Substring($column.StartingIndex, $fieldLength).TrimEnd()
                    $item.Add($column.Name, $columndata)
                }
            }
            
            $items += $item
        }
    }
    return $items
}

Export-ModuleMember -Function ParseSpaceDelimitedList

class ColumnInfo
{
    [string]$Name
    [int32]$StartingIndex
    [int32]$Length
}

function ParseSpaceDelimitedHeaderLine
{
    [CmdletBinding()]
    [OutputType([ColumnInfo[]])]
    param(
        [Parameter(Position = 0, Mandatory)]
        #Header line to be parsed
        [String]$HeaderLine
    )
    
    [ColumnInfo[]]$columns = @()
    [String]$remainingHeaderLine = $HeaderLine
    [int32]$widthConsumedSoFar = 0
    while ($true)
    {
        [ColumnInfo]$info = [ColumnInfo]::new()
        $info.StartingIndex = $widthConsumedSoFar
        [int32]$nextDoubleSpaceIndex = $remainingHeaderLine.IndexOf('  ')
        if ($nextDoubleSpaceIndex -lt 0)
        {
            $info.Name = $remainingHeaderLine.Trim()
            $info.Length = 9999
        }
        else
        {
            $info.Name = $remainingHeaderLine.Substring(0, $nextDoubleSpaceIndex).Trim()
            $info.Length = $nextDoubleSpaceIndex
            while ($remainingHeaderLine.Substring($info.Length, 1) -eq ' ')
            {
                $info.Length += 1
            }
        }
        $columns += $info
        if ($info.Length -gt $remainingHeaderLine.Length)
        {
            return $columns
        }
        $widthConsumedSoFar += $info.Length
        $remainingHeaderLine = $remainingHeaderLine.Substring($info.Length)
    }
}


