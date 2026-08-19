param(
    [switch]$SkipCompile,
    [switch]$UseRealData
)

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pomPath = Join-Path $repositoryRoot "pom.xml"

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "compile.ps1")
}

[xml]$pom = Get-Content -LiteralPath $pomPath
$versionNode = Select-Xml -Xml $pom -XPath "/*[local-name()='project']/*[local-name()='version']"
$version = $versionNode.Node.InnerText
$jarPath = Join-Path $repositoryRoot "target\NoteBot-$version.jar"

if (-not (Test-Path -LiteralPath $jarPath)) {
    throw "The application JAR was not found: $jarPath"
}

$javaCommand = Get-Command java -ErrorAction Stop

if ($UseRealData) {
    Write-Host "Starting NoteBot with the data stored in LOCALAPPDATA."
    & $javaCommand.Source -jar $jarPath
}
else {
    $testDataDirectory = Join-Path $repositoryRoot ".local-run\data"
    New-Item -ItemType Directory -Path $testDataDirectory -Force | Out-Null
    Write-Host "Starting NoteBot with isolated test data: $testDataDirectory"
    & $javaCommand.Source "-Dnotebot.dataDir=$testDataDirectory" -jar $jarPath
}

if ($LASTEXITCODE -ne 0) {
    throw "NoteBot finished with exit code $LASTEXITCODE."
}
