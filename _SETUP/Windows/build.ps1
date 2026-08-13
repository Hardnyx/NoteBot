param(
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pomPath = Join-Path $repositoryRoot "pom.xml"
$targetDirectory = Join-Path $repositoryRoot "target"
$packageInput = Join-Path $targetDirectory "jpackage-input"
$packageOutput = Join-Path $targetDirectory "windows"
$distDirectory = Join-Path $repositoryRoot "dist"

[xml]$pom = Get-Content -LiteralPath $pomPath
$versionNode = Select-Xml -Xml $pom -XPath "/*[local-name()='project']/*[local-name()='version']"
$version = $versionNode.Node.InnerText
$jarName = "NoteBot-$version.jar"
$jarPath = Join-Path $targetDirectory $jarName

if (-not $SkipCompile) {
    Push-Location $repositoryRoot
    try {
        & mvn --batch-mode clean package
        if ($LASTEXITCODE -ne 0) {
            throw "Maven build failed."
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $jarPath)) {
    throw "The application JAR was not found: $jarPath"
}

$jpackageCommand = Get-Command jpackage -ErrorAction Stop

if (Test-Path -LiteralPath $packageInput) {
    Remove-Item -LiteralPath $packageInput -Recurse -Force
}
if (Test-Path -LiteralPath $packageOutput) {
    Remove-Item -LiteralPath $packageOutput -Recurse -Force
}

New-Item -ItemType Directory -Path $packageInput | Out-Null
New-Item -ItemType Directory -Path $packageOutput | Out-Null
New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
Copy-Item -LiteralPath $jarPath -Destination (Join-Path $packageInput $jarName)

$jpackageArguments = @(
    "--type", "app-image",
    "--name", "NoteBot",
    "--app-version", $version,
    "--vendor", "Alonso Roman",
    "--description", "Lightweight desktop sticky notes",
    "--copyright", "Original copyright 2016-2020 Federico Dossena; modifications copyright 2026 Alonso Roman",
    "--input", $packageInput,
    "--dest", $packageOutput,
    "--main-jar", $jarName,
    "--main-class", "com.dosse.stickynotes.Main",
    "--icon", (Join-Path $PSScriptRoot "icon.ico"),
    "--add-modules", "java.desktop,java.logging",
    "--java-options", "-Dsun.java2d.dpiaware=true"
)

& $jpackageCommand.Source @jpackageArguments
if ($LASTEXITCODE -ne 0) {
    throw "jpackage failed."
}

$appImage = Join-Path $packageOutput "NoteBot"
$portableArchive = Join-Path $distDirectory "NoteBot-Portable-$version.zip"
if (Test-Path -LiteralPath $portableArchive) {
    Remove-Item -LiteralPath $portableArchive -Force
}
Compress-Archive -LiteralPath $appImage -DestinationPath $portableArchive -CompressionLevel Optimal

$isccCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
)
$isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $isccPath) {
    $isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($isccCommand) {
        $isccPath = $isccCommand.Source
    }
}

if ($isccPath) {
    $env:NOTEBOT_VERSION = $version
    $env:NOTEBOT_SOURCE_DIR = $appImage
    $env:NOTEBOT_OUTPUT_DIR = $distDirectory
    & $isccPath (Join-Path $PSScriptRoot "setup.iss")
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup build failed."
    }
}
else {
    Write-Warning "Inno Setup 6 was not found. The portable package was created without an installer."
}

Write-Host "Windows packages are available in $distDirectory"
