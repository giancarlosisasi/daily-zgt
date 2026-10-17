# Publishes the app self-contained for win-x64 and packs it with Velopack into artifacts\releases.
# The version comes from Directory.Build.props unless -Version is given (the release workflow passes the tag's).
# Set DAILYZGT_SIGN_TEMPLATE to a vpk --signTemplate string (for example a jsign command ending in {{file}}) to sign.
param([string]$Version)

$ErrorActionPreference = 'Stop'
$windows = Split-Path -Parent $PSScriptRoot
$project = Join-Path $windows 'src\DailyZGT\DailyZGT.csproj'
$publish = Join-Path $windows 'artifacts\publish'
$releases = Join-Path $windows 'artifacts\releases'

function Invoke-Native([scriptblock]$Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code ${LASTEXITCODE}: $Command" }
}

$properties = dotnet msbuild $project -getProperty:Version -getProperty:VelopackPackId -getProperty:Product | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not read the version, the pack id and the product name.' }
$packId = $properties.Properties.VelopackPackId
$title = $properties.Properties.Product
if (-not $Version) { $Version = $properties.Properties.Version }

if (Test-Path $publish) { Remove-Item $publish -Recurse -Force }

Invoke-Native { dotnet publish $project -c Release -r win-x64 --self-contained true "-p:Version=$Version" -o $publish }

$arguments = @(
    'pack',
    '--packId', $packId,
    '--packVersion', $Version,
    '--packDir', $publish,
    '--mainExe', 'DailyZGT.exe',
    '--packTitle', $title,
    '--packAuthors', 'Giancarlos Isasi',
    '--icon', (Join-Path $windows 'src\DailyZGT\Assets\AppIcon.ico'),
    '--runtime', 'win-x64',
    '--shortcuts', 'StartMenuRoot',
    '--outputDir', $releases
)
if ($env:DAILYZGT_SIGN_TEMPLATE) { $arguments += @('--signTemplate', $env:DAILYZGT_SIGN_TEMPLATE) }

Push-Location $windows
try {
    Invoke-Native { dotnet tool restore }
    Invoke-Native { dotnet vpk @arguments }
}
finally {
    Pop-Location
}

Write-Host "Packed Daily ZGT $Version ($packId) into $releases"
