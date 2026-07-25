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
    .\scripts\build-save-upload-images.ps1 -Tag helior-001 -VpsHost 159.198.70.19 -VpsUser deploy -PublicBaseUrl https://heliorsoft.com -ApiBaseUrl https://api.heliorsoft.com -TenantId e6d4fc13-feb8-52a0-93bd-f66c795969b1 -DeployAfterUpload

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

    [string]$SshIdentityFile,

    [string]$RemoteDir = '/opt/apps/images',

    [string]$OutputDir = 'dist-images',

    [string]$PublicBaseUrl,

    [string]$ApiBaseUrl,

    [string]$TenantId,

    [string]$CaddySiteAddress,

    [switch]$DeployAfterUpload,

    [switch]$WithWorker,

    [switch]$SkipDeploymentValidation,

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
$DeployScript = Join-Path $PSScriptRoot 'deploy-on-vps.ps1'

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

if ($SkipUpload -and $DeployAfterUpload) {
    throw "DeployAfterUpload cannot be used with SkipUpload"
}

if ($DeployAfterUpload) {
    if ([string]::IsNullOrWhiteSpace($PublicBaseUrl)) {
        throw "PublicBaseUrl is required when DeployAfterUpload is set"
    }

    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw "TenantId is required when DeployAfterUpload is set"
    }

    if (-not (Test-Path $DeployScript)) {
        throw "Missing deploy script: $DeployScript"
    }
}

$SshArgs = @('-p', $SshPort)
$ScpArgs = @('-P', $SshPort)

if (-not [string]::IsNullOrWhiteSpace($SshIdentityFile)) {
    if (-not (Test-Path $SshIdentityFile)) {
        throw "SSH identity file does not exist: $SshIdentityFile"
    }

    $SshArgs += @('-i', $SshIdentityFile)
    $ScpArgs += @('-i', $SshIdentityFile)
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
    ssh @SshArgs $Remote $RemotePrepareCommand
}

Run-Command "Uploading image archives to ${Remote}:$RemoteDir" {
    scp @ScpArgs $SvcTar $GatewayTar $UiTar "${Remote}:$RemoteDir/"
}

if ($DeployAfterUpload) {
    $DeployArgs = @(
        '-Tag', $Tag,
        '-VpsHost', $VpsHost,
        '-VpsUser', $VpsUser,
        '-SshPort', $SshPort,
        '-PublicBaseUrl', $PublicBaseUrl,
        '-TenantId', $TenantId,
        '-Deploy'
    )

    if (-not [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        $DeployArgs += @('-ApiBaseUrl', $ApiBaseUrl)
    }

    if (-not [string]::IsNullOrWhiteSpace($SshIdentityFile)) {
        $DeployArgs += @('-SshIdentityFile', $SshIdentityFile)
    }

    if (-not [string]::IsNullOrWhiteSpace($CaddySiteAddress)) {
        $DeployArgs += @('-CaddySiteAddress', $CaddySiteAddress)
    }

    if ($WithWorker) {
        $DeployArgs += '-WithWorker'
    }

    if ($SkipDeploymentValidation) {
        $DeployArgs += '-SkipValidation'
    }

    Run-Command "Deploying uploaded images on $Remote" {
        & $DeployScript @DeployArgs
    }

    exit 0
}

Write-Host ""
Write-Host "Done. Image archives uploaded successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Next deployment command:" -ForegroundColor Yellow
Write-Host "  .\scripts\deploy-on-vps.ps1 -Tag $Tag -VpsHost $VpsHost -VpsUser $VpsUser -PublicBaseUrl https://heliorsoft.com -ApiBaseUrl https://api.heliorsoft.com -TenantId <tenant-id> -Deploy"
