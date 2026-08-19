param()

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$sourceDirectory = Join-Path $repositoryRoot "StickyNotes\src"
$targetDirectory = Join-Path $repositoryRoot "target"
$classesDirectory = Join-Path $targetDirectory "classes"
$pomPath = Join-Path $repositoryRoot "pom.xml"

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

[xml]$pom = Get-Content -LiteralPath $pomPath
$versionNode = Select-Xml -Xml $pom -XPath "/*[local-name()='project']/*[local-name()='version']"
$version = $versionNode.Node.InnerText
$jarPath = Join-Path $targetDirectory "NoteBot-$version.jar"

$javacCommand = Get-Command javac -ErrorAction Stop
$jarCommand = Get-Command jar -ErrorAction Stop
$javaFiles = @(Get-ChildItem -LiteralPath $sourceDirectory -Recurse -Filter "*.java" -File | ForEach-Object FullName)

if ($javaFiles.Count -eq 0) {
    throw "No Java source files were found in $sourceDirectory"
}

if (Test-Path -LiteralPath $classesDirectory) {
    Remove-Item -LiteralPath $classesDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $classesDirectory -Force | Out-Null

Invoke-NativeCommand -FilePath $javacCommand.Source `
    -ArgumentList (@("--release", "17", "-encoding", "UTF-8", "-d", $classesDirectory) + $javaFiles) `
    -FailureMessage "javac failed."

Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File |
    Where-Object { $_.Extension -ne ".java" } |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($sourceDirectory.Length + 1)
        $destination = Join-Path $classesDirectory $relativePath
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }

if (Test-Path -LiteralPath $jarPath) {
    Remove-Item -LiteralPath $jarPath -Force
}

Invoke-NativeCommand -FilePath $jarCommand.Source `
    -ArgumentList @("--create", "--file", $jarPath, "--main-class", "com.dosse.stickynotes.Main", "-C", $classesDirectory, ".") `
    -FailureMessage "The application JAR could not be created."

if (-not (Test-Path -LiteralPath $jarPath)) {
    throw "The application JAR could not be created."
}

Write-Host "JAR created: $jarPath"
