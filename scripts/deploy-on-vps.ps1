<#
.SYNOPSIS
    Prepare and deploy KabiPay Docker images on the VPS.

.DESCRIPTION
    This script is intended to run after build-save-upload-images.ps1.
    It can sync the compose template, create/update runtime UI config,
    create/update the Caddyfile, load uploaded image archives, and run
    docker compose on the VPS.

    With -SyncEnvExample, the script uploads .env.example and reconciles
    /opt/apps/.env from it after creating a timestamped backup.

.EXAMPLE
    .\scripts\deploy-on-vps.ps1 -Tag helior-001 -VpsHost 159.198.70.19 -VpsUser deploy -PublicBaseUrl https://heliorsoft.com -ApiBaseUrl https://api.heliorsoft.com -TenantId e6d4fc13-feb8-52a0-93bd-f66c795969b1 -SyncCompose -SyncEnvExample -SyncCaddyfile -LoadImages -Up

.EXAMPLE
    .\scripts\deploy-on-vps.ps1 -Tag helior-001 -VpsHost 159.198.70.19 -VpsUser deploy -PublicBaseUrl https://heliorsoft.com -ApiBaseUrl https://api.heliorsoft.com -TenantId e6d4fc13-feb8-52a0-93bd-f66c795969b1 -Deploy

.EXAMPLE
    .\scripts\deploy-on-vps.ps1 -Tag helior-002 -VpsHost 159.198.70.19 -VpsUser deploy -PublicBaseUrl https://heliorsoft.com -ApiBaseUrl https://api.heliorsoft.com -TenantId e6d4fc13-feb8-52a0-93bd-f66c795969b1 -LoadImages -Up
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9_.-]+$')]
    [string]$Tag,

    [Parameter(Mandatory = $true)]
    [string]$VpsHost,

    [string]$VpsUser = 'deploy',

    [int]$SshPort = 22,

    [string]$SshIdentityFile,

    [string]$AppDir = '/opt/apps',

    [string]$ImageDir = '/opt/apps/images',

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https?://')]
    [string]$PublicBaseUrl,

    [ValidatePattern('^https?://')]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$TenantId,

    [string]$CaddySiteAddress,

    [switch]$Deploy,

    [switch]$SyncCompose,

    [switch]$SyncEnvExample,

    [switch]$SyncCaddyfile,

    [switch]$LoadImages,

    [switch]$Up,

    [switch]$Validate,

    [switch]$SkipValidation,

    [switch]$WithWorker
)

$ErrorActionPreference = 'Stop'

$ProjectDocumentationDir = Split-Path -Parent $PSScriptRoot
$ComposeTemplate = Join-Path $ProjectDocumentationDir 'deploy/docker-compose.prod.yml'
$EnvExample = Join-Path $ProjectDocumentationDir 'deploy/.env.example'
$CaddyfileTemplate = Join-Path $ProjectDocumentationDir 'deploy/Caddyfile.example'

$PublicBaseUrl = $PublicBaseUrl.TrimEnd('/')
$PublicUri = [Uri]$PublicBaseUrl
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = $PublicBaseUrl
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
$Remote = "${VpsUser}@${VpsHost}"

$RemoteComposePath = "$AppDir/docker-compose.yml"
$RemoteEnvExamplePath = "$AppDir/.env.example"
$RemoteCaddyfilePath = "$AppDir/Caddyfile"
$RemoteUiConfigPath = "$AppDir/config/ui-config.json"
$RemoteEnvReconcileScriptPath = "$AppDir/config/kabipay-reconcile-env.sh"
$RemoteValidationScriptPath = "$AppDir/config/kabipay-validate-deploy.sh"

$SvcTarName = "kabipay-svc-$Tag.tar"
$GatewayTarName = "kabipay-gateway-$Tag.tar"
$UiTarName = "kabipay-ui-$Tag.tar"

function Require-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found on PATH"
    }
}

function Assert-NoSingleQuote {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowEmptyString()]
        [string]$Value
    )

    if ($null -ne $Value -and $Value.Contains("'")) {
        throw "$Name cannot contain a single quote"
    }
}

function Quote-Sh {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    return "'$Value'"
}

function Run-Command {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host "==> $Description" -ForegroundColor Cyan

    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE"
    }
}

function Invoke-Remote {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$RemoteCommand
    )

    Run-Command $Description {
        ssh @SshArgs $Remote $RemoteCommand
    }
}

function Copy-ToRemote {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$LocalPath,

        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    if (-not (Test-Path $LocalPath)) {
        throw "Missing local file: $LocalPath"
    }

    Run-Command $Description {
        scp @ScpArgs $LocalPath "${Remote}:$RemotePath"
    }
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $Encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $NormalizedContent = $Content.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($Path, $NormalizedContent, $Encoding)
}

Require-Command ssh
Require-Command scp

$SshArgs = @('-p', $SshPort)
$ScpArgs = @('-P', $SshPort)

if (-not [string]::IsNullOrWhiteSpace($SshIdentityFile)) {
    if (-not (Test-Path $SshIdentityFile)) {
        throw "SSH identity file does not exist: $SshIdentityFile"
    }

    $SshArgs += @('-i', $SshIdentityFile)
    $ScpArgs += @('-i', $SshIdentityFile)
}

Assert-NoSingleQuote -Name 'VpsHost' -Value $VpsHost
Assert-NoSingleQuote -Name 'VpsUser' -Value $VpsUser
Assert-NoSingleQuote -Name 'AppDir' -Value $AppDir
Assert-NoSingleQuote -Name 'ImageDir' -Value $ImageDir
Assert-NoSingleQuote -Name 'PublicBaseUrl' -Value $PublicBaseUrl
Assert-NoSingleQuote -Name 'ApiBaseUrl' -Value $ApiBaseUrl
Assert-NoSingleQuote -Name 'TenantId' -Value $TenantId
Assert-NoSingleQuote -Name 'CaddySiteAddress' -Value $CaddySiteAddress

if (-not (Test-Path $ComposeTemplate)) {
    throw "Missing compose template: $ComposeTemplate"
}

if (-not (Test-Path $EnvExample)) {
    throw "Missing env example: $EnvExample"
}

if ($Deploy) {
    $SyncCompose = $true
    $SyncEnvExample = $true
    $SyncCaddyfile = $true
    $LoadImages = $true
    $Up = $true
}

if ($Up -and -not $SkipValidation) {
    $Validate = $true
}

if ([string]::IsNullOrWhiteSpace($CaddySiteAddress)) {
    if ($PublicUri.Scheme -eq 'http') {
        $CaddySiteAddress = ':80'
    } else {
        $CaddySiteAddress = $PublicUri.Host
    }
}

$AppDirQ = Quote-Sh $AppDir
$ConfigDirQ = Quote-Sh "$AppDir/config"
$ImageDirQ = Quote-Sh $ImageDir
$TagQ = Quote-Sh $Tag
$PublicBaseUrlQ = Quote-Sh $PublicBaseUrl
$ApiBaseUrlQ = Quote-Sh $ApiBaseUrl
$RemoteEnvReconcileScriptPathQ = Quote-Sh $RemoteEnvReconcileScriptPath
$RemoteValidationScriptPathQ = Quote-Sh $RemoteValidationScriptPath
$WithWorkerFlag = if ($WithWorker) { '1' } else { '0' }
$WithWorkerFlagQ = Quote-Sh $WithWorkerFlag
$TempFiles = @()

try {
    $UiConfig = [ordered]@{
        gatewayUrl = "$ApiBaseUrl/graphql"
        authUrl = $ApiBaseUrl
        devTenantId = $TenantId.ToLowerInvariant()
    }

    $UiConfigPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "kabipay-ui-config-$Tag.json")
    $UiConfig | ConvertTo-Json | Set-Content -Path $UiConfigPath -Encoding UTF8
    $TempFiles += $UiConfigPath

    if ((Test-Path $CaddyfileTemplate) -and -not $PSBoundParameters.ContainsKey('CaddySiteAddress')) {
        $CaddyfilePath = $CaddyfileTemplate
    } else {
        $CaddyfilePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "kabipay-Caddyfile-$Tag")
        $CaddyfileContent = @"
$CaddySiteAddress {
    encode gzip

    handle /graphql* {
        reverse_proxy kabipay-gateway:4009
    }

    handle /auth/* {
        reverse_proxy kabipay-auth:4001
    }

    handle /healthz {
        reverse_proxy kabipay-auth:4001
    }

    handle {
        reverse_proxy kabipay-ui:80
    }
}
"@
        Set-Content -Path $CaddyfilePath -Value $CaddyfileContent -Encoding UTF8
        $TempFiles += $CaddyfilePath
    }

    $EnvReconcileScriptPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "kabipay-reconcile-env-$Tag.sh")
    $EnvReconcileScriptContent = @'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$1"
TAG="$2"

cd "$APP_DIR"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

get_env_value() {
    local file="$1"
    local key="$2"
    awk -F= -v key="$key" '$1 == key { value = substr($0, length(key) + 2) } END { print value }' "$file"
}

set_env_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp

    tmp="$(mktemp)"
    awk -v key="$key" -v value="$value" '
        BEGIN { done = 0 }
        $0 ~ "^" key "=" {
            print key "=" value
            done = 1
            next
        }
        { print }
        END {
            if (!done) {
                print key "=" value
            }
        }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

remove_env_key() {
    local file="$1"
    local key="$2"
    local tmp

    tmp="$(mktemp)"
    awk -v key="$key" '$0 !~ "^" key "=" { print }' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

test -f .env.example || fail "$APP_DIR/.env.example does not exist"

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example."
else
    cp .env ".env.backup.$(date +%Y%m%d-%H%M%S)"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
            *=*)
                key="${line%%=*}"
                value="${line#*=}"
                set_env_value .env "$key" "$value"
                ;;
        esac
    done < .env.example
fi

set_env_value .env KABIPAY_IMAGE_TAG "$TAG"

if [ -z "$(get_env_value .env POSTGRES_HOST)" ]; then
    fail "POSTGRES_HOST is missing in $APP_DIR/.env"
fi
if [ -z "$(get_env_value .env POSTGRES_PORT)" ]; then
    fail "POSTGRES_PORT is missing in $APP_DIR/.env"
fi
if [ -z "$(get_env_value .env POSTGRES_DB)" ]; then
    fail "POSTGRES_DB is missing in $APP_DIR/.env"
fi
if [ -z "$(get_env_value .env POSTGRES_USER)" ]; then
    fail "POSTGRES_USER is missing in $APP_DIR/.env"
fi
if [ -z "$(get_env_value .env POSTGRES_PASSWORD)" ]; then
    fail "POSTGRES_PASSWORD is missing in $APP_DIR/.env"
fi
if [ "$(get_env_value .env POSTGRES_HOST)" != "postgres" ]; then
    fail "POSTGRES_HOST must be postgres for containers on the compose network"
fi
if [ "$(get_env_value .env POSTGRES_PORT)" != "5432" ]; then
    fail "POSTGRES_PORT must be 5432 for containers on the compose network; use POSTGRES_HOST_PORT for the VPS host port"
fi

jwt_secret="$(get_env_value .env KABIPAY_JWT_SECRET)"
if [ -z "$jwt_secret" ]; then
    jwt_secret="$(get_env_value .env KABIPAY_CLIENT_JWT_SECRET)"
fi
if [ -z "$jwt_secret" ]; then
    jwt_secret="$(get_env_value .env KABIPAY_OPERATOR_JWT_SECRET)"
fi
if [ -z "$jwt_secret" ]; then
    fail "KABIPAY_JWT_SECRET is missing in $APP_DIR/.env"
fi
set_env_value .env KABIPAY_JWT_SECRET "$jwt_secret"

remove_env_key .env KABIPAY_CLIENT_JWT_SECRET
remove_env_key .env KABIPAY_OPERATOR_JWT_SECRET
remove_env_key .env KABIPAY_CLIENT_JWT_EXPIRY_HOURS
remove_env_key .env KABIPAY_OPERATOR_JWT_EXPIRY_HOURS
remove_env_key .env KABIPAY_CLIENT_REFRESH_EXPIRY_DAYS

echo "==> Effective deployment environment"
printf 'KABIPAY_IMAGE_TAG=%s\n' "$(get_env_value .env KABIPAY_IMAGE_TAG)"
printf 'POSTGRES_HOST=%s\n' "$(get_env_value .env POSTGRES_HOST)"
printf 'POSTGRES_PORT=%s\n' "$(get_env_value .env POSTGRES_PORT)"
printf 'POSTGRES_DB=%s\n' "$(get_env_value .env POSTGRES_DB)"
printf 'POSTGRES_USER=%s\n' "$(get_env_value .env POSTGRES_USER)"
printf 'POSTGRES_PASSWORD=%s\n' '[set]'
printf 'KABIPAY_JWT_SECRET=%s\n' '[set]'
'@
    Write-Utf8NoBomFile -Path $EnvReconcileScriptPath -Content $EnvReconcileScriptContent
    $TempFiles += $EnvReconcileScriptPath

    $ValidationScriptPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "kabipay-validate-deploy-$Tag.sh")
    $ValidationScriptContent = @'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$1"
IMAGE_DIR="$2"
TAG="$3"
PUBLIC_BASE_URL="$4"
API_BASE_URL="$5"
WITH_WORKER="${6:-0}"

cd "$APP_DIR"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

warn() {
    echo "WARN: $*" >&2
}

echo "==> Validating image archives"
for archive in "kabipay-svc-$TAG.tar" "kabipay-gateway-$TAG.tar" "kabipay-ui-$TAG.tar"; do
    test -f "$IMAGE_DIR/$archive" || fail "Missing image archive: $IMAGE_DIR/$archive"
done

echo "==> Validating loaded Docker images"
for image in "kabipay-svc:$TAG" "kabipay-gateway:$TAG" "kabipay-ui:$TAG"; do
    docker image inspect "$image" >/dev/null || fail "Docker image is not loaded: $image"
done

echo "==> Validating docker compose config"
KABIPAY_IMAGE_TAG="$TAG" docker compose config --quiet

echo "==> Waiting for required containers"
required=(caddy postgres mongo kabipay-auth kabipay-subgraphs kabipay-gateway kabipay-ui)
if [ "$WITH_WORKER" = "1" ]; then
    required+=(kabipay-outbox-worker)
fi

dump_container_logs() {
    echo "==> Recent logs for unhealthy containers"
    for container in "$@"; do
        echo "--- $container logs ---"
        docker logs "$container" --tail=80 2>&1 || true
    done
}

deadline=$((SECONDS + 120))
while true; do
    missing=()
    not_running=()
    not_healthy=()
    failed=()

    for container in "${required[@]}"; do
        state="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
        if [ -z "$state" ]; then
            missing+=("$container")
            continue
        fi

        if [ "$state" != "running" ]; then
            not_running+=("$container:$state")
            failed+=("$container")
        fi

        health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || true)"
        if [ "$health" != "none" ] && [ "$health" != "healthy" ]; then
            not_healthy+=("$container:$health")
            failed+=("$container")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ] && [ "${#not_running[@]}" -eq 0 ] && [ "${#not_healthy[@]}" -eq 0 ]; then
        break
    fi

    if [ "$SECONDS" -ge "$deadline" ]; then
        docker compose ps || true
        if [ "${#failed[@]}" -gt 0 ]; then
            dump_container_logs "${failed[@]}"
        fi
        [ "${#missing[@]}" -eq 0 ] || fail "Missing containers: ${missing[*]}"
        [ "${#not_running[@]}" -eq 0 ] || fail "Containers not running: ${not_running[*]}"
        [ "${#not_healthy[@]}" -eq 0 ] || fail "Containers not healthy: ${not_healthy[*]}"
    fi

    sleep 5
done

docker compose ps

echo "==> Validating public HTTP routes"
command -v curl >/dev/null 2>&1 || fail "curl is required on the VPS for HTTP validation"

curl -fsS --max-time 10 "$PUBLIC_BASE_URL/" >/dev/null || fail "UI is not reachable at $PUBLIC_BASE_URL/"
curl -fsS --max-time 10 "$PUBLIC_BASE_URL/config.json" >/tmp/kabipay-ui-config.json || fail "UI config is not reachable at $PUBLIC_BASE_URL/config.json"
grep -q '"gatewayUrl"' /tmp/kabipay-ui-config.json || fail "UI config does not contain gatewayUrl"
grep -q '"authUrl"' /tmp/kabipay-ui-config.json || fail "UI config does not contain authUrl"
tr -d '[:space:]' < /tmp/kabipay-ui-config.json > /tmp/kabipay-ui-config.compact.json
grep -Fq "\"gatewayUrl\":\"$API_BASE_URL/graphql\"" /tmp/kabipay-ui-config.compact.json || fail "UI config gatewayUrl does not match $API_BASE_URL/graphql"
grep -Fq "\"authUrl\":\"$API_BASE_URL\"" /tmp/kabipay-ui-config.compact.json || fail "UI config authUrl does not match $API_BASE_URL"
curl -fsS --max-time 10 "$API_BASE_URL/healthz" >/dev/null || fail "Auth health is not reachable at $API_BASE_URL/healthz"
curl -fsS --max-time 10 -X POST -H 'content-type: application/json' --data '{"query":"{ __typename }"}' "$API_BASE_URL/graphql" | grep -q '"data"' || fail "Gateway GraphQL is not reachable at $API_BASE_URL/graphql"

echo "==> Deployment validation passed"
'@
    Write-Utf8NoBomFile -Path $ValidationScriptPath -Content $ValidationScriptContent
    $TempFiles += $ValidationScriptPath

    Invoke-Remote "Creating remote app directories on $Remote" "set -eu; mkdir -p $AppDirQ $ConfigDirQ $ImageDirQ"

    Copy-ToRemote "Uploading runtime UI config" $UiConfigPath $RemoteUiConfigPath

    if ($SyncCaddyfile) {
        Copy-ToRemote "Uploading Caddyfile" $CaddyfilePath $RemoteCaddyfilePath
    } else {
        Write-Host "==> Skipping Caddyfile sync. Use -SyncCaddyfile to update $RemoteCaddyfilePath." -ForegroundColor Yellow
    }

    if ($SyncCompose) {
        Copy-ToRemote "Uploading docker-compose.yml" $ComposeTemplate $RemoteComposePath
    } else {
        Write-Host "==> Skipping compose sync. Use -SyncCompose for first deployment or compose changes." -ForegroundColor Yellow
    }

    if ($SyncEnvExample) {
        Copy-ToRemote "Uploading .env.example" $EnvExample $RemoteEnvExamplePath
        Copy-ToRemote "Uploading environment reconciliation script" $EnvReconcileScriptPath $RemoteEnvReconcileScriptPath
        Invoke-Remote "Reconciling remote .env from .env.example" "set -eu; bash $RemoteEnvReconcileScriptPathQ $AppDirQ $TagQ"
    }

    if ($LoadImages) {
        $LoadCommand = "set -eu; cd $ImageDirQ; test -f $SvcTarName; test -f $GatewayTarName; test -f $UiTarName; docker load -i $SvcTarName; docker load -i $GatewayTarName; docker load -i $UiTarName"
        Invoke-Remote "Loading uploaded Docker images" $LoadCommand
    } else {
        Write-Host "==> Skipping docker load. Use -LoadImages after image archives are uploaded." -ForegroundColor Yellow
    }

    if ($Up) {
        $ProfileArgs = ''

        if ($WithWorker) {
            $ProfileArgs = '--profile worker '
        }

        Invoke-Remote "Starting KabiPay containers with docker compose" "set -eu; cd $AppDirQ; test -f docker-compose.yml; test -f .env; KABIPAY_IMAGE_TAG=$TagQ docker compose $ProfileArgs up -d"
        $AppServices = 'caddy kabipay-auth kabipay-subgraphs kabipay-gateway kabipay-ui'

        if ($WithWorker) {
            $AppServices = "$AppServices kabipay-outbox-worker"
        }

        Invoke-Remote "Recreating KabiPay app containers with current env" "set -eu; cd $AppDirQ; KABIPAY_IMAGE_TAG=$TagQ docker compose $ProfileArgs up -d --force-recreate $AppServices"
    } else {
        Write-Host "==> Skipping docker compose up. Use -Up when you are ready to recreate containers." -ForegroundColor Yellow
    }

    if ($Validate) {
        Copy-ToRemote "Uploading deployment validation script" $ValidationScriptPath $RemoteValidationScriptPath
        Invoke-Remote "Running deployment validation" "set -eu; bash $RemoteValidationScriptPathQ $AppDirQ $ImageDirQ $TagQ $PublicBaseUrlQ $ApiBaseUrlQ $WithWorkerFlagQ"
    } else {
        Write-Host "==> Skipping deployment validation. Use -Validate or -Deploy to run image, compose, container, and HTTP checks." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Deployment commands completed." -ForegroundColor Green
    Write-Host ""
    Write-Host "Deployment target:" -ForegroundColor Yellow
    Write-Host "  UI:  $PublicBaseUrl"
    Write-Host "  API: $ApiBaseUrl"
} finally {
    foreach ($TempFile in $TempFiles) {
        if (Test-Path $TempFile) {
            Remove-Item -LiteralPath $TempFile -Force
        }
    }
}
