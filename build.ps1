<#
.SYNOPSIS
This is a Powershell script to bootstrap a Fake build.
.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Fake)
and execute your Fake build script with the parameters you provide.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER WhatIf
Performs a dry run of the build script.
No tasks will be executed.
.PARAMETER ScriptArgs
Remaining arguments are added here.
#>

[CmdletBinding()]
Param(
    [string]$Target = "Default",
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [switch]$WhatIf,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

$FakeVersion = "4.63.0"
$NugetVersion = "5.8.0";
$NugetUrl = "https://dist.nuget.org/win-x86-commandline/v$NugetVersion/nuget.exe"
$ProtobufVersion = "3.13.0"
$DocfxVersion = "2.58.9"

$IncrementalistVersion = "0.6.0";

# Make sure tools folder exists
$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$ToolPath = Join-Path $PSScriptRoot "tools"
if (!(Test-Path $ToolPath)) {
    Write-Verbose "Creating tools directory..."
    New-Item -Path $ToolPath -Type directory | out-null
}

###########################################################################
# INSTALL NUGET
###########################################################################

# Make sure nuget.exe exists.
$NugetPath = Join-Path $ToolPath "nuget.exe"
if (!(Test-Path $NugetPath)) {
    Write-Host "Downloading NuGet.exe..."
    (New-Object System.Net.WebClient).DownloadFile($NugetUrl, $NugetPath);
}

###########################################################################
# INSTALL FAKE
###########################################################################
# Make sure Fake has been installed.

$FakeExePath = Join-Path $ToolPath "FAKE/tools/FAKE.exe"
if (!(Test-Path $FakeExePath)) {
    Write-Host "Installing Fake..."
    Invoke-Expression "&`"$NugetPath`" install Fake -ExcludeVersion -Version $FakeVersion -OutputDirectory `"$ToolPath`"" | Out-Null;
    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring Fake from NuGet."
    }
}

###########################################################################
# Google.Protobuf.Tools
###########################################################################

# Make sure Google.Protobuf.Tools has been installed.
$ProtobufExePath = Join-Path $ToolPath "Google.Protobuf.Tools/tools/windows_x64/protoc.exe"
if (!(Test-Path $ProtobufExePath)) {
    Write-Host "Installing Google.Protobuf.Tools..."
    Invoke-Expression "&`"$NugetPath`" install Google.Protobuf.Tools -ExcludeVersion -Version $ProtobufVersion -OutputDirectory `"$ToolPath`"" | Out-Null;
    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring Google.Protobuf.Tools from NuGet."
    }
}

###########################################################################
# Docfx
###########################################################################

# Make sure Docfx has been installed.
$DocfxExePath = Join-Path $ToolPath "docfx.console/tools/docfx.exe"
if (!(Test-Path $DocfxExePath)) {
    Write-Host "Installing Docfx..."
    Invoke-Expression "&`"$NugetPath`" install docfx.console -ExcludeVersion -Version $DocfxVersion -OutputDirectory `"$ToolPath`"" | Out-Null;
    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring docfx.console from NuGet."
    }
}

###########################################################################
# Incrementalist
###########################################################################

# Make sure the Incrementalist has been installed
if (Get-Command incrementalist -ErrorAction SilentlyContinue) {
    Write-Host "Found Incrementalist. Skipping install."
}
else{
    $IncrementalistFolder = Join-Path $ToolPath "incrementalist"
    Write-Host "Incrementalist not found. Installing to ... $IncrementalistFolder"
    dotnet tool install Incrementalist.Cmd --version $IncrementalistVersion --tool-path "$IncrementalistFolder"
}

###########################################################################
# RUN BUILD SCRIPT
###########################################################################

# Build the argument list.
$Arguments = @{
    target=$Target;
    configuration=$Configuration;
    verbosity=$Verbosity;
    dryrun=$WhatIf;
}.GetEnumerator() | %{"--{0}=`"{1}`"" -f $_.key, $_.value };

# Start Fake
Write-Host "Running build script..."
Invoke-Expression "& `"$FakeExePath`" `"build.fsx`" $ScriptArgs $Arguments"
 
exit $LASTEXITCODE