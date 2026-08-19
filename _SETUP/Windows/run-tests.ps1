<#
    Compiles the application and runs the regression checks in
    StickyNotes\test. The checks cover the resize floor, the zoom limits, the pin
    state and the storage round trip, and they use a temporary data folder so the
    real notes are never touched.
#>

param(
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$testSourceDirectory = Join-Path $repositoryRoot "StickyNotes\test"
$targetDirectory = Join-Path $repositoryRoot "target"
$classesDirectory = Join-Path $targetDirectory "classes"
$testClassesDirectory = Join-Path $targetDirectory "test-classes"
$testDataDirectory = Join-Path $repositoryRoot ".local-run\test-data"

function Invoke-NativeCommand {
    <#
        Runs an external program with both output streams merged into plain text.

        A native program that writes to standard error becomes a terminating
        NativeCommandError as soon as the caller redirects the stream while
        ErrorActionPreference is Stop. javac, java, jpackage and ISCC all write ordinary
        progress and warning messages there, so the streams are merged here and the
        result is decided by the exit code instead.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [string]$FailureMessage = "The external command failed."
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @ArgumentList 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" }
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        throw ($FailureMessage + " Exit code: " + $exitCode)
    }
}

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "compile.ps1")
}

if (-not (Test-Path -LiteralPath $classesDirectory)) {
    throw "The compiled classes were not found: $classesDirectory"
}

$javacCommand = Get-Command javac -ErrorAction Stop
$javaCommand = Get-Command java -ErrorAction Stop
$testFiles = @(Get-ChildItem -LiteralPath $testSourceDirectory -Recurse -Filter "*.java" -File | ForEach-Object FullName)

if (Test-Path -LiteralPath $testClassesDirectory) {
    Remove-Item -LiteralPath $testClassesDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $testClassesDirectory -Force | Out-Null

Invoke-NativeCommand -FilePath $javacCommand.Source `
    -ArgumentList (@("-encoding", "UTF-8", "-nowarn", "-cp", $classesDirectory, "-d", $testClassesDirectory) + $testFiles) `
    -FailureMessage "The tests could not be compiled."

if (Test-Path -LiteralPath $testDataDirectory) {
    Remove-Item -LiteralPath $testDataDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $testDataDirectory -Force | Out-Null

Invoke-NativeCommand -FilePath $javaCommand.Source `
    -ArgumentList @("-Dnotebot.dataDir=$testDataDirectory", "-cp", "$classesDirectory;$testClassesDirectory", "com.dosse.stickynotes.SmokeTest") `
    -FailureMessage "One or more checks failed."
