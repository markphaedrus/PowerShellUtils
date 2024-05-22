Set-StrictMode -Version Latest

[String]$libraryPath = Split-Path -Parent $PSScriptRoot
If (-Not ($env:PSModulePath.Contains($libraryPath)))
{
    $env:PSModulePath += ";$libraryPath"
}

Import-Module MHP-PesterUtility -Force

InitializePesterTest -ModuleName "MHP-ArchiveOperations"

BeforeAll {
    [String]$script:corpusDir = GetTestCorpusDirectory -ModuleName "MHP-ArchiveOperations"
    [String]$script:zipPath = Join-Path -Path $script:corpusDir -ChildPath "TestZIP.zip"
    [String]$script:cabPath = Join-Path -Path $script:corpusDir -ChildPath "testcab.cab"
    [String]$script:textPath = Join-Path -Path $script:corpusDir -ChildPath "testtext.txt"
    [String]$script:nonexistentPath = Join-Path -Path $script:corpusDir -ChildPath "nosuchfile.xxx"
}

# Tests run outside of module scope
describe 'IsFileUnpackableArchive' {
    Context "ZIP file" {
        It "should return true" {
            IsFileUnpackableArchive -File $script:zipPath | Should -BeTrue
        }
    }
    Context "CAB file" {
        It "should return true" {
            IsFileUnpackableArchive -File $script:cabPath | Should -BeTrue
        }
    }
    Context "text file" {
        It "should return false" {
            IsFileUnpackableArchive -File $script:textPath | Should -BeFalse
        }
    }
}

describe 'UnpackArchiveFile' {
    BeforeEach {
        [String]$script:unpackTempDir = CreateTempDirectory
    }
    AfterEach {
        if (-Not [String]::IsNullOrWhitespace($script:unpackTempDir))
        {
            DeleteTempDirectory -Path $script:unpackTempDir
        }
    }
    Context 'ZIP file' {
        It "should have expected format and contents" {
            UnpackArchiveFile -File $script:zipPath -UnpackDirectoryPath $script:unpackTempDir
            (Join-Path -Path $script:unpackTempDir -ChildPath 'RootLevelFile.txt') | Should -FileContentMatch 'File at root level'
            (Join-Path -Path $script:unpackTempDir -ChildPath 'Subdir/SubdirLevelFile.txt') | Should -FileContentMatch 'File at subdirectory level'
        }
    }
    Context 'CAB file' {
        It "should have expected format and contents" {
            UnpackArchiveFile -File $script:cabPath -UnpackDirectoryPath $script:unpackTempDir
            (Join-Path -Path $script:unpackTempDir -ChildPath 'RootLevelFile.txt') | Should -FileContentMatch 'File at root level'
            (Join-Path -Path $script:unpackTempDir -ChildPath 'Subdir/SubdirLevelFile.txt') | Should -FileContentMatch 'File at subdirectory level'
        }
    }
    Context 'text file' {
        It "should throw" {
            { UnpackArchiveFile -File $script:textPath -UnpackDirectoryPath $script:unpackTempDir } | Should -Throw
        }
    }
    Context 'nonexisting file' {
        It "should throw" {
            { UnpackArchiveFile -File $script:nonexistentPath -UnpackDirectoryPath $script:unpackTempDir } | Should -Throw
        }
    }
}
