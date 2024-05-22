Set-StrictMode -Version Latest
$Error.Clear()

[String]$libraryPath = Split-Path -Parent $PSScriptRoot
If (-Not ($env:PSModulePath.Contains($libraryPath)))
{
    $env:PSModulePath += ";$libraryPath"
}

Import-Module MHP-PesterUtility -Force

InitializePesterTest -ModuleName "MHP-Debugging"

# Tests run outside of module scope
describe 'GetObjectArrayDescription' {
    Context "multi-object array" {
        It "should be five lines of array description" {
            [String]$description = GetObjectArrayDescription @('Hello', 23, $null, 45)
            $description | Should -Be "4 objects:`r`n     0: Hello`r`n     1: 23`r`n     2: (`$null)`r`n     3: 45`r`n"
        }
    }
    Context "single-object array" {
        It "should be two lines of array description" {
            [String]$description = GetObjectArrayDescription @('Hello')
            $description | Should -Be "1 object:`r`n     0: Hello`r`n"
        }
    }
    Context "empty array" {
        It "should be 'Empty array'" {
            [String]$description = GetObjectArrayDescription @()
            $description | Should -Be "Empty array`r`n"
        }
    }
    Context "null" {
        It "should be 'Null array'" {
            [String]$description = GetObjectArrayDescription $null
            $description | Should -Be "Null array`r`n"
        }
    }
}
describe 'GetTestCorpusDirectory' {
    Context 'this module' {
        It "should be directory with Test file" {
            [String]$thisModuleCorpusPath = GetTestCorpusDirectory -ModuleName 'CSD-Debugging'
            [String]$testFile = Join-Path -Path $thisModuleCorpusPath -ChildPath 'GetTestCorpusDirectoryTest.txt'
            $testFile | Should -FileContentMatch 'Corpus directory test'
        }
    }
}
