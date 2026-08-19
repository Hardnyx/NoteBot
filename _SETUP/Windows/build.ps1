<#
    Builds the Windows package.

    By default the script compiles the source, runs the regression checks and produces a
    single file, dist\NoteBot-Setup-<version>.exe, which is the normal way to install
    NoteBot. The portable folder is optional and is only produced when -Portable is
    passed.

    Signing is optional but strongly recommended before distributing the result. Without a
    signature Windows SmartScreen warns every person who downloads the installer.
#>

param(
    [switch]$SkipCompile,
    [switch]$SkipTests,
    [switch]$Portable,
    [string]$IsccPath,
    [string]$SignPfx,
    [string]$SignTimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pomPath = Join-Path $repositoryRoot "pom.xml"
$targetDirectory = Join-Path $repositoryRoot "target"
$packageRoot = Join-Path $targetDirectory "windows-packages"
$packageInput = Join-Path $packageRoot "input"
$installedOutput = Join-Path $packageRoot "installed"
$portableOutput = Join-Path $packageRoot "portable"
$portableStaging = Join-Path $packageRoot "portable-staging"
$distDirectory = Join-Path $repositoryRoot "dist"

[xml]$pom = Get-Content -LiteralPath $pomPath
$versionNode = Select-Xml -Xml $pom -XPath "/*[local-name()='project']/*[local-name()='version']"
$version = $versionNode.Node.InnerText
$jarName = "NoteBot-$version.jar"
$jarPath = Join-Path $targetDirectory $jarName

function Invoke-NativeCommand {
    <#
        Runs an external program with both output streams merged into plain text.

        A native program that writes to standard error becomes a terminating
        NativeCommandError as soon as the caller redirects the stream while
        ErrorActionPreference is Stop. jpackage, ISCC and signtool all write ordinary
        progress messages there, so the streams are merged here and the result is decided
        by the exit code instead.
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

function Find-InnoSetupCompiler {
    <#
        Inno Setup can be installed per machine, per user or into a custom folder, so the
        entries left by its own installer are consulted before falling back to the usual
        locations.
    #>

    if ($IsccPath) {
        if (-not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
            throw "The path given in -IsccPath does not exist: $IsccPath"
        }
        return (Resolve-Path -LiteralPath $IsccPath).Path
    }

    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $fromRegistry = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Inno Setup*" -and $_.InstallLocation } |
        Sort-Object DisplayName -Descending |
        ForEach-Object { Join-Path $_.InstallLocation.TrimEnd("\") "ISCC.exe" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if ($fromRegistry) {
        return $fromRegistry
    }

    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA "Programs"))) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        $found = Get-ChildItem -LiteralPath $root -Directory -Filter "Inno Setup*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "ISCC.exe" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1

        if ($found) {
            return $found
        }
    }

    return $null
}

function Find-SignTool {
    $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    foreach ($root in @(
        (Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"),
        (Join-Path $env:ProgramFiles "Windows Kits\10\bin")
    )) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        $found = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "x64\signtool.exe" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1

        if ($found) {
            return $found
        }
    }

    return $null
}

function Invoke-Signing {
    <#
        Signs one file with the certificate given in -SignPfx. A signature is what actually
        removes the SmartScreen warning; everything else only reduces the chance of a
        heuristic false positive.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not $SignPfx) {
        return
    }

    $signTool = Find-SignTool
    if (-not $signTool) {
        throw "signtool.exe was not found. Install the Windows SDK signing tools, or build without -SignPfx."
    }

    if (-not $script:SignPassword) {
        $script:SignPassword = Read-Host "Certificate password" -AsSecureString
    }

    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:SignPassword))

    try {
        Invoke-NativeCommand -FilePath $signTool `
            -ArgumentList @("sign", "/fd", "SHA256", "/td", "SHA256", "/tr", $SignTimestampUrl,
                            "/f", $SignPfx, "/p", $plainPassword, $Path) `
            -FailureMessage "Signing failed for $Path."
    }
    finally {
        $plainPassword = $null
    }
}

if (-not $SkipCompile) {
    & (Join-Path $PSScriptRoot "compile.ps1")
}

if (-not $SkipTests) {
    Write-Host "Running the regression checks before packaging."
    & (Join-Path $PSScriptRoot "run-tests.ps1") -SkipCompile
}

if (-not (Test-Path -LiteralPath $jarPath)) {
    throw "The application JAR was not found: $jarPath"
}

$mainSource = Get-Content -LiteralPath (Join-Path $repositoryRoot "StickyNotes\src\com\dosse\stickynotes\Main.java") -Raw
if ($mainSource -notmatch ('VERSION\s*=\s*"' + [regex]::Escape($version) + '"')) {
    throw "Main.VERSION and pom.xml do not contain the same version."
}

$jarCommand = Get-Command jar -ErrorAction Stop
$jarEntries = @(& $jarCommand.Source --list --file $jarPath)
if ($LASTEXITCODE -ne 0) {
    throw "The application JAR could not be inspected."
}
foreach ($requiredEntry in @(
    "com/dosse/stickynotes/Main.class",
    "com/dosse/stickynotes/ComponentResizer.class",
    "com/dosse/stickynotes/PinIcon.class",
    "com/dosse/stickynotes/ZoomDialog.class",
    "com/dosse/stickynotes/icon.png",
    "com/dosse/stickynotes/locale/locale.properties"
)) {
    if ($jarEntries -notcontains $requiredEntry) {
        throw "The application JAR is incomplete. Missing: $requiredEntry"
    }
}

$jpackageCommand = Get-Command jpackage -ErrorAction Stop

$isccPath = Find-InnoSetupCompiler

if (-not $isccPath -and -not $Portable) {
    throw "Inno Setup 6 or 7 is required to build the installer. Install it from https://jrsoftware.org/isdl.php, or run this script with -Portable to build the portable folder instead."
}

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $packageInput -Force | Out-Null
New-Item -ItemType Directory -Path $installedOutput -Force | Out-Null
New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
Copy-Item -LiteralPath $jarPath -Destination (Join-Path $packageInput $jarName) -Force

$commonJpackageArguments = @(
    "--type", "app-image",
    "--name", "NoteBot",
    "--app-version", $version,
    "--vendor", "Alonso Roman",
    "--description", "Lightweight desktop sticky notes",
    "--copyright", "Original copyright 2016-2020 Federico Dossena; modifications copyright 2026 Alonso Roman",
    "--input", $packageInput,
    "--main-jar", $jarName,
    "--main-class", "com.dosse.stickynotes.Main",
    "--icon", (Join-Path $PSScriptRoot "icon.ico"),
    "--add-modules", "java.desktop,java.logging",
    "--java-options", "-Dsun.java2d.dpiaware=true",
    "--java-options", "-Djava.awt.headless=false"
)

function Invoke-NoteBotJPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        [switch]$PortableImage
    )

    $arguments = @($commonJpackageArguments) + @("--dest", $Destination)
    if ($PortableImage) {
        $arguments += @("--java-options", '-Dnotebot.dataDir=$ROOTDIR\data')
    }

    Invoke-NativeCommand -FilePath $jpackageCommand.Source -ArgumentList $arguments -FailureMessage "jpackage failed."
}

function Assert-NoteBotImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ImagePath,
        [switch]$PortableImage
    )

    $packagedJar = Join-Path $ImagePath "app\$jarName"
    foreach ($requiredPath in @(
        (Join-Path $ImagePath "NoteBot.exe"),
        $packagedJar,
        (Join-Path $ImagePath "app\NoteBot.cfg"),
        (Join-Path $ImagePath "runtime\bin\server\jvm.dll")
    )) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "The packaged application is incomplete. Missing: $requiredPath"
        }
    }

    $sourceHash = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash
    $packagedHash = (Get-FileHash -LiteralPath $packagedJar -Algorithm SHA256).Hash
    if ($sourceHash -ne $packagedHash) {
        throw "The packaged JAR differs from the compiled and tested JAR."
    }

    if ($PortableImage) {
        $configuration = Get-Content -LiteralPath (Join-Path $ImagePath "app\NoteBot.cfg") -Raw
        if ($configuration -notmatch 'notebot\.dataDir=\$ROOTDIR\\data') {
            throw "The portable launcher was created without its portable data directory."
        }
    }
}

Invoke-NoteBotJPackage -Destination $installedOutput
$installedImage = Join-Path $installedOutput "NoteBot"
Assert-NoteBotImage -ImagePath $installedImage
Invoke-Signing -Path (Join-Path $installedImage "NoteBot.exe")

if ($isccPath) {
    $env:NOTEBOT_VERSION = $version
    $env:NOTEBOT_SOURCE_DIR = $installedImage
    $env:NOTEBOT_OUTPUT_DIR = $distDirectory
    $env:NOTEBOT_LICENSE_FILE = (Join-Path $repositoryRoot "LICENSE")
    Invoke-NativeCommand -FilePath $isccPath `
        -ArgumentList @((Join-Path $PSScriptRoot "setup.iss")) `
        -FailureMessage "Inno Setup build failed."

    $installerPath = Join-Path $distDirectory "NoteBot-Setup-$version.exe"
    if (-not (Test-Path -LiteralPath $installerPath)) {
        throw "The installer was not produced: $installerPath"
    }

    Invoke-Signing -Path $installerPath
    Write-Host "Installer: $installerPath"
}

if ($Portable) {
    New-Item -ItemType Directory -Path $portableOutput -Force | Out-Null
    New-Item -ItemType Directory -Path $portableStaging -Force | Out-Null

    Invoke-NoteBotJPackage -Destination $portableOutput -PortableImage
    $portableImage = Join-Path $portableOutput "NoteBot"
    Assert-NoteBotImage -ImagePath $portableImage -PortableImage
    Invoke-Signing -Path (Join-Path $portableImage "NoteBot.exe")

    $portableBundle = Join-Path $portableStaging "NoteBot-Portable-$version"
    New-Item -ItemType Directory -Path $portableBundle -Force | Out-Null
    Copy-Item -LiteralPath $portableImage -Destination (Join-Path $portableBundle "NoteBot") -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "PORTABLE-README.txt") -Destination (Join-Path $portableBundle "README.txt")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "LICENSE") -Destination (Join-Path $portableBundle "LICENSE.txt")

    $portableArchive = Join-Path $distDirectory "NoteBot-Portable-$version.zip"
    if (Test-Path -LiteralPath $portableArchive) {
        Remove-Item -LiteralPath $portableArchive -Force
    }
    Compress-Archive -LiteralPath $portableBundle -DestinationPath $portableArchive -CompressionLevel Optimal
    Write-Host "Portable package: $portableArchive"
}

# A published checksum lets anyone confirm that the file they downloaded is the file that
# was built here, which is the only verification available without a code signing
# certificate.
$checksumPath = Join-Path $distDirectory "SHA256SUMS.txt"
Get-ChildItem -LiteralPath $distDirectory -File |
    Where-Object { $_.Name -ne "SHA256SUMS.txt" } |
    ForEach-Object { "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash, $_.Name } |
    Set-Content -LiteralPath $checksumPath -Encoding ASCII

Write-Host ""
Write-Host "Windows packages are available in $distDirectory"
Get-Content -LiteralPath $checksumPath | ForEach-Object { Write-Host "  $_" }

if (-not $SignPfx) {
    Write-Host ""
    Write-Host "The output is not signed, so Windows SmartScreen will warn everyone who downloads it."
    Write-Host "Pass -SignPfx with a code signing certificate to remove that warning."
}
