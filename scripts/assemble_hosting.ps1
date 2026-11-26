<#
.SYNOPSIS
  Assembles the single deploy folder containing Flutter Web at the root and Next.js static export under /admin.
.DESCRIPTION
  1. Verifies Flutter Web build exists at build/web.
  2. Runs Next.js static build in admin_web (output: 'export', basePath: '/admin').
  3. Creates public_deploy directory.
  4. Copies build/web/* into public_deploy.
  5. Copies admin_web/out/* into public_deploy/admin.
#>

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " ProntoChat Same-Origin Hosting Assembly Pipeline" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$RootPath = (Get-Item $PSScriptRoot).Parent.FullName
$FlutterBuildPath = Join-Path $RootPath "build\web"
$AdminWebPath = Join-Path $RootPath "admin_web"
$AdminOutPath = Join-Path $AdminWebPath "out"
$DeployPath = Join-Path $RootPath "public_deploy"

# 1. Verify Flutter Web Build
Write-Host "`n[1/4] Checking Flutter Web build output at $FlutterBuildPath..." -ForegroundColor Yellow
if (-not (Test-Path $FlutterBuildPath)) {
  Write-Error "Flutter Web build not found at $FlutterBuildPath. Please run 'flutter build web' first."
}
Write-Host "  ✓ Found Flutter Web build artifacts." -ForegroundColor Green

# 2. Build Next.js Static Export
Write-Host "`n[2/4] Building Next.js static export in $AdminWebPath..." -ForegroundColor Yellow
Push-Location $AdminWebPath
try {
  & npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "Next.js build failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

if (-not (Test-Path $AdminOutPath)) {
  Write-Error "Next.js export directory not found at $AdminOutPath"
}
Write-Host "  ✓ Next.js static export generated successfully." -ForegroundColor Green

# 3. Clean and Prepare Deploy Directory
Write-Host "`n[3/4] Preparing public_deploy directory..." -ForegroundColor Yellow
if (Test-Path $DeployPath) {
  Remove-Item -Path $DeployPath -Recurse -Force
}
New-Item -ItemType Directory -Path $DeployPath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DeployPath "admin") -Force | Out-Null

# 4. Copy Artifacts
Write-Host "`n[4/4] Assembling same-origin deploy tree..." -ForegroundColor Yellow
Write-Host "  -> Copying Flutter Web to root (public_deploy/)..."
Copy-Item -Path "$FlutterBuildPath\*" -Destination $DeployPath -Recurse -Force

Write-Host "  -> Copying Next.js export to /admin (public_deploy/admin/)..."
Copy-Item -Path "$AdminOutPath\*" -Destination (Join-Path $DeployPath "admin") -Recurse -Force

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "✅ ASSEMBLY COMPLETE: public_deploy ready for same-origin testing!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "To test on ONE local port with Firebase Hosting Emulator:"
Write-Host "  firebase emulators:start --only auth,firestore,hosting"
Write-Host "Then navigate to:"
Write-Host "  Flutter App:  http://localhost:5000/"
Write-Host "  Next.js Admin: http://localhost:5000/admin/"
Write-Host "==================================================================`n"

