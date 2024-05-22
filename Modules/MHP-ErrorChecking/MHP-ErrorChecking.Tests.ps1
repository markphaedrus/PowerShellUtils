Set-StrictMode -Version Latest
$Error.Clear()

[String]$libraryPath = Split-Path -Parent $PSScriptRoot
If (-Not ($env:PSModulePath.Contains($libraryPath)))
{
    $env:PSModulePath += ";$libraryPath"
}

Import-Module MHP-PesterUtility -Force

InitializePesterTest -ModuleName "MHP-ErrorChecking"

BeforeAll {
    [String]$script:corpusDir = GetTestCorpusDirectory -ModuleName "MHP-ErrorChecking"
    [String]$script:existingFile = Join-Path -Path $script:corpusDir -ChildPath "ExistingFile.txt"
    [String]$script:nonexistingFile = Join-Path -Path $script:corpusDir -ChildPath "NonexistingFile.txt"
    [String]$script:nonexistingFolder = Join-Path -Path $script:corpusDir -ChildPath "NonExistingFolder"
    [String]$script:fileInNonexistingFolder = Join-Path -Path $script:nonexistingFolder -ChildPath "NonexistingFile.txt"
    [String]$script:nonexistingLongerPath = Join-Path -Path $script:nonexistingFolder -ChildPath "AnotherFolder/AndAnother"
}

# Tests run outside of module scope
describe 'IsNullOrEmptyArray' {
    Context 'Multi-item array' {
        It 'should return false' {
            IsNullOrEmptyArray @(1,2,3,4) | Should -BeFalse
        }
    }
    Context 'Single-item array' {
        It 'should return false' {
            IsNullOrEmptyArray @(1) | Should -BeFalse
        }
    }
    Context 'Single item' {
        It 'should return false' {
            IsNullOrEmptyArray 1 | Should -BeFalse
        }
    }
    Context 'Empty array' {
        It 'should return true' {
            IsNullOrEmptyArray @() | Should -BeTrue
        }
    }
    Context 'Null' {
        It 'should return true' {
            IsNullOrEmptyArray $null | Should -BeTrue
        }
    }
}

describe 'ValidateFullPath' {
    Context 'Existing folder' {
        It "should return empty string" {
            (ValidateFullPath -Path $script:corpusDir) | Should -Be ""
        }
    }
    Context 'Existing file' {
        It "should return empty string" {
            (ValidateFullPath -Path $script:existingFile) | Should -Be ""
        }
    }
    context 'Existing folder, but tested for file' {
        It "should return same path" {
            (ValidateFullPath -Path $script:corpusDir -PathType Leaf) | Should -Be $script:corpusDir
        }
    }
    context 'Existing file, but tested for folder' {
        It "should return same path" {
            (ValidateFullPath -Path $script:existingFile -PathType Container) | Should -Be $script:existingFile
        }
    }
    context "Nonexisting file" {
        It "should return same path" {
            (ValidateFullPath -Path $script:nonexistingFile) | Should -Be $script:nonexistingFile
        }
    }
    context "Nonexisting folder" {
        It "should return same path" {
            (ValidateFullPath -Path $script:nonexistingFolder) | Should -Be $script:nonexistingFolder
        }
    }
    context "File in nonexisting folder" {
        It "should return nonexisting folder" {
            (ValidateFullPath -Path $script:fileInNonexistingFolder) | Should -Be $script:nonexistingFolder
        }
    }
    context "Subfolder in nonexisting folder" {
        It "should return nonexisting folder" {
            (ValidateFullPath -Path $script:nonexistingLongerPath) | Should -Be $script:nonexistingFolder
        }
    }
}