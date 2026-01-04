param(
  [string]$Image = "ghcr.io/milesburton/devcontainer-template",
  [string]$Tag = "latest",
  [string]$Dockerfile = ".devcontainer/Dockerfile",
  [string]$RegistryUser = "milesburton"
)

$ErrorActionPreference = "Stop"

$token = $env:GHCR_TOKEN
if (-not $token) { $token = $env:GHCR_PAT }
if (-not $token) {
  Write-Error "GHCR_TOKEN or GHCR_PAT environment variable is required (with read:packages, write:packages)."
}

Write-Host "Logging into GHCR as '$RegistryUser'..."
$login = docker login ghcr.io -u $RegistryUser --password-stdin
$token | & $login

Write-Host "Building image $Image:$Tag from $Dockerfile ..."
 docker build -f $Dockerfile -t "$Image:$Tag" .

try {
  $sha = git rev-parse --short HEAD
  if ($LASTEXITCODE -eq 0 -and $sha) {
    docker tag "$Image:$Tag" "$Image:$sha"
    Write-Host "Tagged SHA: $Image:$sha"
  }
} catch {
  Write-Host "Git not available; skipping SHA tag"
}

Write-Host "Pushing $Image:$Tag ..."
 docker push "$Image:$Tag"

if ($sha) {
  Write-Host "Pushing $Image:$sha ..."
  docker push "$Image:$sha"
}

Write-Host "Done. Verify locally:"
Write-Host "  docker images $Image"
