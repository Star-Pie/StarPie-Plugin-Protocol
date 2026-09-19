#Requires -Version 7.2

<#
.SYNOPSIS
    Generates deterministic StarPie community registry index and catalog files.
.DESCRIPTION
    Publisher, plugin, and version files are the source of truth. This script creates
    registry/index.json and registry/generated/community-catalog.json without executing
    plugin code. Use -Check in CI to detect generated-file drift.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),

    [Parameter()]
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)

    return Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
}

function ConvertTo-DeterministicJson {
    param([Parameter(Mandatory)]$InputObject)

    $json = $InputObject | ConvertTo-Json -Depth 40
    return (($json -replace "
", "
").TrimEnd() + "
")
}

function Get-SourceDigest {
    param([Parameter(Mandatory)][AllowEmptyCollection()][System.IO.FileInfo[]]$Files)

    $builder = [System.Text.StringBuilder]::new()
    foreach ($file in ($Files | Sort-Object FullName)) {
        $relative = [System.IO.Path]::GetRelativePath($RepositoryRoot, $file.FullName).Replace('\', '/')
        $content = [System.IO.File]::ReadAllText($file.FullName) -replace "
", "
"
        [void]$builder.Append($relative).Append("
").Append($content.TrimEnd()).Append("
")
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Write-OrCheckFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    if ($Check) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Generated file is missing: $Path"
        }

        $existing = ([System.IO.File]::ReadAllText($Path) -replace "
", "
").TrimEnd() + "
"
        if (-not [string]::Equals($existing, $Content, [StringComparison]::Ordinal)) {
            throw "Generated file is stale: $Path. Run tools/Update-CommunityCatalog.ps1."
        }

        return
    }

    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

$registryRoot = Join-Path $RepositoryRoot 'registry'
$publisherRoot = Join-Path $registryRoot 'publishers'
$pluginRoot = Join-Path $registryRoot 'plugins'

$publisherFiles = @(
    if (Test-Path -LiteralPath $publisherRoot) {
        Get-ChildItem -LiteralPath $publisherRoot -Filter '*.json' -File
    }
)
$pluginFiles = @(
    if (Test-Path -LiteralPath $pluginRoot) {
        Get-ChildItem -LiteralPath $pluginRoot -Filter 'plugin.json' -File -Recurse
    }
)
$versionFiles = @(
    if (Test-Path -LiteralPath $pluginRoot) {
        Get-ChildItem -LiteralPath $pluginRoot -Filter '*.json' -File -Recurse |
            Where-Object { $_.Directory.Name -eq 'versions' }
    }
)
$sourceFiles = @($publisherFiles + $pluginFiles + $versionFiles)
$sourceDigest = Get-SourceDigest -Files $sourceFiles

$publisherById = @{}
$catalogPublishers = @(
    foreach ($file in ($publisherFiles | Sort-Object Name)) {
        $publisher = Read-JsonFile -Path $file.FullName
        $publisherById[$publisher.publisherId] = $publisher
        [ordered]@{
            publisherId = $publisher.publisherId
            displayName = $publisher.displayName
            identity = [ordered]@{
                provider = $publisher.identity.provider
                login = $publisher.identity.login
                userId = $publisher.identity.userId
                profileUrl = $publisher.identity.profileUrl
            }
            namespaces = @($publisher.namespaces)
            securityContact = $publisher.securityContact
            status = $publisher.status
        }
    }
)

$indexPlugins = [System.Collections.Generic.List[object]]::new()
$catalogPlugins = [System.Collections.Generic.List[object]]::new()

foreach ($pluginFile in ($pluginFiles | Sort-Object FullName)) {
    $plugin = Read-JsonFile -Path $pluginFile.FullName
    $pluginDirectory = Split-Path -Parent $pluginFile.FullName
    $versionsDirectory = Join-Path $pluginDirectory 'versions'
    $versions = @(
        if (Test-Path -LiteralPath $versionsDirectory) {
            foreach ($versionFile in (Get-ChildItem -LiteralPath $versionsDirectory -Filter '*.json' -File | Sort-Object Name)) {
                Read-JsonFile -Path $versionFile.FullName
            }
        }
    )

    $relativeManifest = [System.IO.Path]::GetRelativePath($registryRoot, $pluginFile.FullName).Replace('\', '/')
    $indexPlugins.Add([ordered]@{
        id = $plugin.id
        manifest = $relativeManifest
    })

    $publisher = $publisherById[$plugin.publisherId]
    $catalogPlugins.Add([ordered]@{
        id = $plugin.id
        publisherId = $plugin.publisherId
        publisher = if ($null -ne $publisher) { $publisher.displayName } else { $null }
        name = $plugin.name
        description = $plugin.description
        repository = $plugin.repository
        homepage = $plugin.homepage
        license = $plugin.license
        categories = @($plugin.categories)
        paths = @($plugin.paths)
        declaredCapabilities = @($plugin.declaredCapabilities)
        channels = $plugin.channels
        status = $plugin.status
        replacedBy = $plugin.replacedBy
        createdAt = $plugin.createdAt
        versions = @($versions)
    })
}

$index = [ordered]@{
    schemaVersion = 1
    catalog = 'generated/community-catalog.json'
    sourceDigest = $sourceDigest
    plugins = @($indexPlugins)
}

$catalog = [ordered]@{
    schemaVersion = 1
    catalogType = 'community'
    sourceDigest = $sourceDigest
    publishers = @($catalogPublishers)
    plugins = @($catalogPlugins)
}

$indexPath = Join-Path $registryRoot 'index.json'
$catalogPath = Join-Path $registryRoot 'generated/community-catalog.json'
Write-OrCheckFile -Path $indexPath -Content (ConvertTo-DeterministicJson -InputObject $index)
Write-OrCheckFile -Path $catalogPath -Content (ConvertTo-DeterministicJson -InputObject $catalog)

if ($Check) {
    Write-Host 'Community registry generated files are up to date.'
}
else {
    Write-Host "Generated $indexPath"
    Write-Host "Generated $catalogPath"
}
