<#
.SYNOPSIS
    Build KabiPay Docker images locally, save them as tar archives, and upload them to a VPS.

.DESCRIPTION
    This script builds Docker images on the local machine only.
    It does not upload source code to the VPS.
    It saves images as .tar archives and uploads them using SCP.

.EXAMPLE
    .\scripts\build-save-upload-images.ps1 -Tag helior-001 -VpsHost 159.198.70.19 -VpsUser deploy

.EXAMPLE
    .\scripts\build-save-upload-images.ps1 -Tag helior-001 -VpsHost 159.198.70.19 -VpsUser deploy -SshPort 22 -RemoteDir /opt/apps/images

.EXAMPLE
    .\scripts\build-save-upload-images.ps1 -Tag helior-001 -SkipUpload
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9_.-]+$')]
    [string]$Tag,

    [string]$VpsHost,

    [string]$VpsUser = 'deploy',

    [int]$SshPort = 22,

    [string]$RemoteDir = '/opt/apps/images',

    [string]$OutputDir = 'dist-images',

    [switch]$SkipUpload
)

$ErrorActionPreference = 'Stop'

$ProjectDocumentationDir = Split-Path -Parent $PSScriptRoot
$Root = Split-Path -Parent $ProjectDocumentationDir

$SvcDir = Join-Path $Root 'kabipay-svc'
$GatewayDir = Join-Path $Root 'kabipay-gateway'
$UiDir = Join-Path $Root 'kabipay-ui'
$OutDir = Join-Path $Root $OutputDir

$SvcImage = "kabipay-svc:$Tag"
$GatewayImage = "kabipay-gateway:$Tag"
$UiImage = "kabipay-ui:$Tag"

$SvcTarName = "kabipay-svc-$Tag.tar"
$GatewayTarName = "kabipay-gateway-$Tag.tar"
$UiTarName = "kabipay-ui-$Tag.tar"

$SvcTar = Join-Path $OutDir $SvcTarName
$GatewayTar = Join-Path $OutDir $GatewayTarName
$UiTar = Join-Path $OutDir $UiTarName

function Require-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found on PATH"
    }
}

function Run-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host "==> $Description" -ForegroundColor Cyan

    & $Command

    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE"
    }
}

Require-Command docker

if (-not $SkipUpload) {
    Require-Command ssh
    Require-Command scp

    if ([string]::IsNullOrWhiteSpace($VpsHost)) {
        throw "VpsHost is required unless -SkipUpload is set"
    }

    if ([string]::IsNullOrWhiteSpace($VpsUser)) {
        throw "VpsUser is required unless -SkipUpload is set"
    }
}

if (-not (Test-Path (Join-Path $SvcDir 'Dockerfile'))) {
    throw "Missing Dockerfile in $SvcDir"
}

if (-not (Test-Path (Join-Path $GatewayDir 'Dockerfile'))) {
    throw "Missing Dockerfile in $GatewayDir"
}

if (-not (Test-Path (Join-Path $UiDir 'Dockerfile'))) {
    throw "Missing Dockerfile in $UiDir"
}

if ($RemoteDir.Contains("'")) {
    throw "RemoteDir cannot contain a single quote"
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Run-Command "Building $SvcImage" {
    docker build -t $SvcImage $SvcDir
}

Run-Command "Building $GatewayImage" {
    docker build -t $GatewayImage $GatewayDir
}

Run-Command "Building $UiImage" {
    docker build -t $UiImage $UiDir
}

Run-Command "Saving $SvcImage to $SvcTar" {
    docker save $SvcImage -o $SvcTar
}

Run-Command "Saving $GatewayImage to $GatewayTar" {
    docker save $GatewayImage -o $GatewayTar
}

Run-Command "Saving $UiImage to $UiTar" {
    docker save $UiImage -o $UiTar
}

if ($SkipUpload) {
    Write-Host ""
    Write-Host "Upload skipped. Image archives are ready:" -ForegroundColor Green
    Write-Host "  $SvcTar"
    Write-Host "  $GatewayTar"
    Write-Host "  $UiTar"
    exit 0
}

$Remote = "${VpsUser}@${VpsHost}"
$DeploymentStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$RemoteArchiveDir = "$RemoteDir/archive/$DeploymentStamp"
$RemotePrepareCommand = "set -eu; mkdir -p '$RemoteDir' '$RemoteDir/archive'; if ls '$RemoteDir'/kabipay-*.tar >/dev/null 2>&1; then mkdir -p '$RemoteArchiveDir'; mv '$RemoteDir'/kabipay-*.tar '$RemoteArchiveDir'/; fi"

Run-Command "Preparing remote image directory and archive on $Remote" {
    ssh -p $SshPort $Remote $RemotePrepareCommand
}

Run-Command "Uploading image archives to ${Remote}:$RemoteDir" {
    scp -P $SshPort $SvcTar $GatewayTar $UiTar "${Remote}:$RemoteDir/"
}

Write-Host ""
Write-Host "Done. Image archives uploaded successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Next commands to run on VPS:" -ForegroundColor Yellow
Write-Host "  ssh -p $SshPort $Remote"
Write-Host "  cd $RemoteDir"
Write-Host "  docker load -i $SvcTarName"
Write-Host "  docker load -i $GatewayTarName"
Write-Host "  docker load -i $UiTarName"
Write-Host "  docker images | grep kabipay"
Write-Host ""
Write-Host "Then update /opt/apps/docker-compose.yml with:"
Write-Host "  image: kabipay-svc:$Tag"
Write-Host "  image: kabipay-gateway:$Tag"
Write-Host "  image: kabipay-ui:$Tag"
Write-Host ""
Write-Host "Then run:"
Write-Host "  cd /opt/apps"
Write-Host "  docker compose up -d"
