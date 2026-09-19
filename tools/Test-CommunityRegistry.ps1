#Requires -Version 7.2

<#
.SYNOPSIS
    Validates the StarPie community publisher, plugin, version, and package registry.
.DESCRIPTION
    Performs structural, ownership, compatibility, immutability, and static package
    checks. Plugin assemblies are never loaded or executed.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),

    [Parameter()]
    [switch]$VerifyPackages,

    [Parameter()]
    [string]$BaseRevision,

    [Parameter()]
    [string]$PullRequestActor,

    [Parameter()]
    [long]$PullRequestActorId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Errors = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()
$script:SemVerPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'
$script:PluginIdPattern = '^io\.github\.[a-z0-9-]+(?:\.[a-z0-9][a-z0-9-]*)+$'
$script:AllowedPaths = @('action-execution', 'interaction-event', 'wheel-structure')
$script:ReservedPrefixes = @('starpie.', 'com.starpie.', 'org.starpie.')

function Add-RegistryError {
    param([Parameter(Mandatory)][string]$Message)
    $script:Errors.Add($Message)
}

function Add-RegistryWarning {
    param([Parameter(Mandatory)][string]$Message)
    $script:Warnings.Add($Message)
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)

    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    }
    catch {
        Add-RegistryError "Invalid JSON in '$Path': $($_.Exception.Message)"
        return $null
    }
}

function Test-FileAgainstSchema {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$SchemaPath
    )

    try {
        if (-not (Test-Json -LiteralPath $Path -SchemaFile $SchemaPath -ErrorAction Stop)) {
            Add-RegistryError "JSON Schema validation failed for '$Path'."
        }
    }
    catch {
        Add-RegistryError "JSON Schema validation failed for '$Path': $($_.Exception.Message)"
    }
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-RequiredProperties {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string[]]$Names,
        [Parameter(Mandatory)][string]$Context
    )

    foreach ($name in $Names) {
        if ($null -eq $Object.PSObject.Properties[$name]) {
            Add-RegistryError "$Context is missing required property '$name'."
        }
    }
}

function Test-ExactSchemaVersion {
    param($Object, [string]$Context)

    $schemaVersion = Get-PropertyValue -Object $Object -Name 'schemaVersion'
    if ($schemaVersion -ne 1) {
        Add-RegistryError "$Context must use schemaVersion 1."
    }
}

function Test-IsoDateTime {
    param($Value, [string]$Context)

    if ($Value -is [DateTime] -or $Value -is [DateTimeOffset]) {
        return
    }

    $parsed = [DateTimeOffset]::MinValue
    if ($Value -isnot [string] -or -not [DateTimeOffset]::TryParse($Value, [ref]$parsed)) {
        Add-RegistryError "$Context must be an ISO-8601 date-time."
    }
}

function Test-UniqueStrings {
    param($Values, [string]$Context)

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($value in @($Values)) {
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
            Add-RegistryError "$Context contains an empty or non-string value."
            continue
        }
        if (-not $seen.Add($value)) {
            Add-RegistryError "$Context contains duplicate value '$value'."
        }
    }
}

function Get-NormalizedRepositoryUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    return $Url.TrimEnd('/').ToLowerInvariant()
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetRelativePath($RepositoryRoot, $Path).Replace('\', '/')
}

function Get-JsonAtRevision {
    param(
        [Parameter(Mandatory)][string]$Revision,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $gitPath = $RelativePath.Replace('\', '/')
    $revisionPath = $Revision + ':' + $gitPath
    $text = & git -C $RepositoryRoot show $revisionPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    try {
        return ($text -join "
") | ConvertFrom-Json
    }
    catch {
        Add-RegistryError "Unable to parse '$gitPath' at revision '$Revision'."
        return $null
    }
}

function Get-ChangedRegistryFiles {
    if ([string]::IsNullOrWhiteSpace($BaseRevision)) {
        return @()
    }

    $lines = & git -C $RepositoryRoot diff --name-status --find-renames "$BaseRevision...HEAD" -- registry/publishers registry/plugins
    if ($LASTEXITCODE -ne 0) {
        Add-RegistryError "Unable to inspect changes from base revision '$BaseRevision'."
        return @()
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($line in $lines) {
        $parts = $line -split "	"
        if ($parts.Count -lt 2) { continue }
        $status = $parts[0]
        $path = if ($status.StartsWith('R') -and $parts.Count -ge 3) { $parts[2] } else { $parts[1] }
        $oldPath = if ($status.StartsWith('R') -and $parts.Count -ge 3) { $parts[1] } else { $path }
        $result.Add([pscustomobject]@{ Status = $status; Path = $path; OldPath = $oldPath })
    }
    return @($result)
}

function Test-ActorAuthorizedForPublisher {
    param(
        [Parameter(Mandatory)]$Publisher,
        [Parameter(Mandatory)][string]$Context
    )

    if ($PullRequestActorId -le 0) {
        return
    }

    $maintainers = @(Get-PropertyValue -Object $Publisher -Name 'maintainers')
    $authorized = @($maintainers | Where-Object { (Get-PropertyValue -Object $_ -Name 'userId') -eq $PullRequestActorId })
    if ($authorized.Count -eq 0) {
        Add-RegistryError "$Context is not owned by pull-request actor '$PullRequestActor' ($PullRequestActorId)."
    }
}

function Get-ImmutableVersionFingerprint {
    param([Parameter(Mandatory)]$Version)

    $immutable = [ordered]@{
        schemaVersion = Get-PropertyValue -Object $Version -Name 'schemaVersion'
        pluginId = Get-PropertyValue -Object $Version -Name 'pluginId'
        version = Get-PropertyValue -Object $Version -Name 'version'
        channel = Get-PropertyValue -Object $Version -Name 'channel'
        publishedAt = Get-PropertyValue -Object $Version -Name 'publishedAt'
        source = Get-PropertyValue -Object $Version -Name 'source'
        compatibility = Get-PropertyValue -Object $Version -Name 'compatibility'
        asset = Get-PropertyValue -Object $Version -Name 'asset'
        capabilities = @(Get-PropertyValue -Object $Version -Name 'capabilities')
    }
    return $immutable | ConvertTo-Json -Depth 20 -Compress
}

function Test-Publisher {
    param(
        [Parameter(Mandatory)]$Publisher,
        [Parameter(Mandatory)][string]$Path
    )

    $context = "Publisher '$Path'"
    Test-ExactSchemaVersion -Object $Publisher -Context $context
    Test-RequiredProperties -Object $Publisher -Context $context -Names @(
        'schemaVersion', 'publisherId', 'displayName', 'identity', 'namespaces',
        'maintainers', 'securityContact', 'terms', 'status'
    )

    $publisherId = Get-PropertyValue -Object $Publisher -Name 'publisherId'
    $identity = Get-PropertyValue -Object $Publisher -Name 'identity'
    if ($null -eq $identity) { return }

    Test-RequiredProperties -Object $identity -Context "$context identity" -Names @('provider', 'login', 'userId', 'profileUrl')
    $login = [string](Get-PropertyValue -Object $identity -Name 'login')
    $userId = Get-PropertyValue -Object $identity -Name 'userId'
    if ((Get-PropertyValue -Object $identity -Name 'provider') -ne 'github') {
        Add-RegistryError "$context currently supports only GitHub identities."
    }
    if ($publisherId -ne "github:$userId") {
        Add-RegistryError "$context publisherId must equal 'github:<identity.userId>'."
    }

    $expectedFileName = "github-$userId.json"
    if ([System.IO.Path]::GetFileName($Path) -ne $expectedFileName) {
        Add-RegistryError "$context file name must be '$expectedFileName'."
    }

    if ($login -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$') {
        Add-RegistryError "$context has an invalid GitHub login."
    }
    $expectedNamespace = "io.github.$($login.ToLowerInvariant())"
    $namespaces = @(Get-PropertyValue -Object $Publisher -Name 'namespaces')
    Test-UniqueStrings -Values $namespaces -Context "$context namespaces"
    if ($namespaces.Count -ne 1 -or $namespaces[0] -cne $expectedNamespace) {
        Add-RegistryError "$context MVP namespace must be exactly '$expectedNamespace'."
    }

    $maintainers = @(Get-PropertyValue -Object $Publisher -Name 'maintainers')
    if ($maintainers.Count -eq 0) {
        Add-RegistryError "$context must declare at least one maintainer."
    }
    $maintainerIds = @()
    $hasIdentityOwner = $false
    foreach ($maintainer in $maintainers) {
        Test-RequiredProperties -Object $maintainer -Context "$context maintainer" -Names @('provider', 'login', 'userId', 'role')
        $maintainerId = Get-PropertyValue -Object $maintainer -Name 'userId'
        $maintainerIds += [string]$maintainerId
        if ((Get-PropertyValue -Object $maintainer -Name 'provider') -ne 'github') {
            Add-RegistryError "$context maintainer provider must be 'github'."
        }
        if ((Get-PropertyValue -Object $maintainer -Name 'role') -notin @('owner', 'maintainer')) {
            Add-RegistryError "$context maintainer role must be owner or maintainer."
        }
        if ($maintainerId -eq $userId -and (Get-PropertyValue -Object $maintainer -Name 'role') -eq 'owner') {
            $hasIdentityOwner = $true
        }
    }
    Test-UniqueStrings -Values $maintainerIds -Context "$context maintainer IDs"
    if (-not $hasIdentityOwner) {
        Add-RegistryError "$context identity must also be an owner maintainer."
    }

    $terms = Get-PropertyValue -Object $Publisher -Name 'terms'
    if ($null -ne $terms) {
        Test-RequiredProperties -Object $terms -Context "$context terms" -Names @('version', 'acceptedAt')
        if ((Get-PropertyValue -Object $terms -Name 'version') -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') {
            Add-RegistryError "$context terms.version must use YYYY-MM-DD."
        }
        Test-IsoDateTime -Value (Get-PropertyValue -Object $terms -Name 'acceptedAt') -Context "$context terms.acceptedAt"
    }

    if ((Get-PropertyValue -Object $Publisher -Name 'status') -notin @('active', 'suspended', 'revoked')) {
        Add-RegistryError "$context has an unsupported status."
    }
}

function Test-Plugin {
    param(
        [Parameter(Mandatory)]$Plugin,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Publishers
    )

    $context = "Plugin '$Path'"
    Test-ExactSchemaVersion -Object $Plugin -Context $context
    Test-RequiredProperties -Object $Plugin -Context $context -Names @(
        'schemaVersion', 'id', 'publisherId', 'name', 'description', 'repository',
        'homepage', 'license', 'categories', 'paths', 'declaredCapabilities',
        'channels', 'status', 'replacedBy', 'createdAt'
    )

    $pluginId = [string](Get-PropertyValue -Object $Plugin -Name 'id')
    if ($pluginId -cne $pluginId.ToLowerInvariant() -or $pluginId -notmatch $script:PluginIdPattern) {
        Add-RegistryError "$context id must be a lowercase io.github.<login>.<plugin> identifier."
    }
    foreach ($prefix in $script:ReservedPrefixes) {
        if ($pluginId.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            Add-RegistryError "$context uses reserved namespace '$prefix'."
        }
    }

    $directoryName = Split-Path -Leaf (Split-Path -Parent $Path)
    if ($directoryName -cne $pluginId) {
        Add-RegistryError "$context directory must be named '$pluginId'."
    }

    $publisherId = [string](Get-PropertyValue -Object $Plugin -Name 'publisherId')
    if (-not $Publishers.ContainsKey($publisherId)) {
        Add-RegistryError "$context references unknown publisher '$publisherId'."
    }
    else {
        $publisher = $Publishers[$publisherId]
        if ((Get-PropertyValue -Object $publisher -Name 'status') -ne 'active') {
            Add-RegistryError "$context publisher '$publisherId' is not active."
        }
        $namespaces = @(Get-PropertyValue -Object $publisher -Name 'namespaces')
        $owned = $false
        foreach ($namespace in $namespaces) {
            if ($pluginId.StartsWith("$namespace.", [StringComparison]::Ordinal)) { $owned = $true }
        }
        if (-not $owned) {
            Add-RegistryError "$context id is outside publisher '$publisherId' namespaces."
        }

        $repository = [string](Get-PropertyValue -Object $Plugin -Name 'repository')
        $identityLogin = [string](Get-PropertyValue -Object (Get-PropertyValue -Object $publisher -Name 'identity') -Name 'login')
        if ($repository -notmatch '^https://github\.com/([^/]+)/([^/]+)/?$') {
            Add-RegistryError "$context repository must be a public GitHub HTTPS repository URL."
        }
        elseif ($Matches[1] -ine $identityLogin) {
            Add-RegistryError "$context repository owner must match publisher GitHub login '$identityLogin' in the MVP."
        }
    }

    Test-UniqueStrings -Values @(Get-PropertyValue -Object $Plugin -Name 'categories') -Context "$context categories"
    $paths = @(Get-PropertyValue -Object $Plugin -Name 'paths')
    Test-UniqueStrings -Values $paths -Context "$context paths"
    foreach ($declaredPath in $paths) {
        if ($declaredPath -notin $script:AllowedPaths) {
            Add-RegistryError "$context declares unsupported path '$declaredPath'."
        }
    }
    Test-UniqueStrings -Values @(Get-PropertyValue -Object $Plugin -Name 'declaredCapabilities') -Context "$context declaredCapabilities"
    Test-IsoDateTime -Value (Get-PropertyValue -Object $Plugin -Name 'createdAt') -Context "$context createdAt"
    if ((Get-PropertyValue -Object $Plugin -Name 'status') -notin @('active', 'deprecated', 'blocked')) {
        Add-RegistryError "$context has an unsupported status."
    }
}

function Test-PluginVersion {
    param(
        [Parameter(Mandatory)]$Version,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Plugin
    )

    $context = "Plugin version '$Path'"
    Test-ExactSchemaVersion -Object $Version -Context $context
    Test-RequiredProperties -Object $Version -Context $context -Names @(
        'schemaVersion', 'pluginId', 'version', 'channel', 'publishedAt', 'source',
        'compatibility', 'asset', 'capabilities', 'status', 'reason', 'replacedBy', 'advisory'
    )

    $pluginId = [string](Get-PropertyValue -Object $Plugin -Name 'id')
    $versionText = [string](Get-PropertyValue -Object $Version -Name 'version')
    if ((Get-PropertyValue -Object $Version -Name 'pluginId') -cne $pluginId) {
        Add-RegistryError "$context pluginId must equal '$pluginId'."
    }
    if ($versionText -notmatch $script:SemVerPattern) {
        Add-RegistryError "$context version '$versionText' is not valid SemVer."
    }
    if ([System.IO.Path]::GetFileNameWithoutExtension($Path) -cne $versionText) {
        Add-RegistryError "$context file name must be '$versionText.json'."
    }
    $channel = Get-PropertyValue -Object $Version -Name 'channel'
    if ($channel -notin @('stable', 'beta')) {
        Add-RegistryError "$context channel must be stable or beta."
    }
    Test-IsoDateTime -Value (Get-PropertyValue -Object $Version -Name 'publishedAt') -Context "$context publishedAt"

    $source = Get-PropertyValue -Object $Version -Name 'source'
    if ($null -ne $source) {
        Test-RequiredProperties -Object $source -Context "$context source" -Names @('repository', 'tag', 'commit')
        if ((Get-NormalizedRepositoryUrl (Get-PropertyValue -Object $source -Name 'repository')) -cne (Get-NormalizedRepositoryUrl (Get-PropertyValue -Object $Plugin -Name 'repository'))) {
            Add-RegistryError "$context source repository must equal the plugin repository."
        }
        if ((Get-PropertyValue -Object $source -Name 'commit') -notmatch '^[0-9a-fA-F]{40}$') {
            Add-RegistryError "$context source.commit must be a full 40-character Git commit SHA."
        }
    }

    $compatibility = Get-PropertyValue -Object $Version -Name 'compatibility'
    if ($null -ne $compatibility) {
        Test-RequiredProperties -Object $compatibility -Context "$context compatibility" -Names @(
            'apiVersion', 'minimumHostVersion', 'maximumHostVersion', 'targetFramework', 'platform'
        )
        if ((Get-PropertyValue -Object $compatibility -Name 'apiVersion') -notmatch '^[0-9]+\.[0-9]+$') {
            Add-RegistryError "$context compatibility.apiVersion must use major.minor."
        }
        if ((Get-PropertyValue -Object $compatibility -Name 'platform') -ne 'win-x64') {
            Add-RegistryError "$context currently supports only win-x64 packages."
        }
    }

    $asset = Get-PropertyValue -Object $Version -Name 'asset'
    if ($null -ne $asset) {
        Test-RequiredProperties -Object $asset -Context "$context asset" -Names @('fileName', 'downloadUrl', 'sha256', 'size')
        $expectedFileName = "$pluginId-$versionText.spkg"
        $fileName = [string](Get-PropertyValue -Object $asset -Name 'fileName')
        if ($fileName -cne $expectedFileName) {
            Add-RegistryError "$context asset.fileName must be '$expectedFileName'."
        }
        $downloadUrl = [string](Get-PropertyValue -Object $asset -Name 'downloadUrl')
        $url = $null
        if (-not [Uri]::TryCreate($downloadUrl, [UriKind]::Absolute, [ref]$url) -or
            $url.Scheme -ne 'https' -or $url.Host -ne 'github.com' -or
            $url.AbsolutePath -notmatch '^/[^/]+/[^/]+/releases/download/([^/]+)/([^/]+\.spkg)$') {
            Add-RegistryError "$context asset.downloadUrl must be a fixed GitHub Release .spkg URL."
        }
        else {
            if ([Uri]::UnescapeDataString($Matches[1]) -cne [string](Get-PropertyValue -Object $source -Name 'tag')) {
                Add-RegistryError "$context release URL tag must equal source.tag."
            }
            if ([Uri]::UnescapeDataString($Matches[2]) -cne $fileName) {
                Add-RegistryError "$context release URL file name must equal asset.fileName."
            }
        }
        if ((Get-PropertyValue -Object $asset -Name 'sha256') -notmatch '^[0-9a-fA-F]{64}$') {
            Add-RegistryError "$context asset.sha256 must contain 64 hexadecimal characters."
        }
        $size = Get-PropertyValue -Object $asset -Name 'size'
        if ($size -isnot [long] -and $size -isnot [int]) {
            Add-RegistryError "$context asset.size must be an integer."
        }
        elseif ($size -le 0 -or $size -gt 104857600) {
            Add-RegistryError "$context asset.size must be between 1 byte and 100 MiB."
        }
    }

    $capabilities = @(Get-PropertyValue -Object $Version -Name 'capabilities')
    Test-UniqueStrings -Values $capabilities -Context "$context capabilities"
    $declaredCapabilities = @(Get-PropertyValue -Object $Plugin -Name 'declaredCapabilities')
    foreach ($capability in $capabilities) {
        if ($capability -cnotin $declaredCapabilities) {
            Add-RegistryError "$context capability '$capability' is not declared by plugin metadata."
        }
    }

    $status = Get-PropertyValue -Object $Version -Name 'status'
    if ($status -notin @('active', 'yanked', 'revoked')) {
        Add-RegistryError "$context has an unsupported status."
    }
    if ($status -ne 'active' -and [string]::IsNullOrWhiteSpace([string](Get-PropertyValue -Object $Version -Name 'reason'))) {
        Add-RegistryError "$context must provide reason when status is '$status'."
    }
}

function Test-Package {
    param(
        [Parameter(Mandatory)]$Version,
        [Parameter(Mandatory)]$Plugin,
        [Parameter(Mandatory)][string]$VersionPath
    )

    $asset = Get-PropertyValue -Object $Version -Name 'asset'
    $url = [string](Get-PropertyValue -Object $asset -Name 'downloadUrl')
    $expectedHash = ([string](Get-PropertyValue -Object $asset -Name 'sha256')).ToLowerInvariant()
    $expectedSize = [long](Get-PropertyValue -Object $asset -Name 'size')
    $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("starpie-package-" + [Guid]::NewGuid().ToString('N'))
    $packagePath = Join-Path $tempDirectory ([string](Get-PropertyValue -Object $asset -Name 'fileName'))

    try {
        [System.IO.Directory]::CreateDirectory($tempDirectory) | Out-Null
        Write-Host "Downloading package for $VersionPath"
        Invoke-WebRequest -Uri $url -OutFile $packagePath -MaximumRedirection 5

        $actualSize = (Get-Item -LiteralPath $packagePath).Length
        if ($actualSize -ne $expectedSize) {
            Add-RegistryError "Package '$VersionPath' size is $actualSize but registry declares $expectedSize."
            return
        }
        $actualHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne $expectedHash) {
            Add-RegistryError "Package '$VersionPath' SHA-256 does not match the registry."
            return
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
        try {
            if ($archive.Entries.Count -gt 512) {
                Add-RegistryError "Package '$VersionPath' contains more than 512 entries."
            }
            $totalLength = [long]0
            $entryNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $archive.Entries) {
                $name = $entry.FullName.Replace('\', '/')
                $segments = $name.Split('/', [StringSplitOptions]::RemoveEmptyEntries)
                if ($name.StartsWith('/') -or $name.Contains(':') -or $segments -contains '..') {
                    Add-RegistryError "Package '$VersionPath' contains unsafe path '$name'."
                }
                if (-not $entryNames.Add($name)) {
                    Add-RegistryError "Package '$VersionPath' contains duplicate path '$name'."
                }
                $totalLength += $entry.Length
                $leafName = [System.IO.Path]::GetFileName($name)
                if ($leafName -in @('StarPie.dll', 'StarPie.Plugin.Abstractions.dll')) {
                    Add-RegistryError "Package '$VersionPath' contains forbidden assembly '$leafName'."
                }
            }
            if ($totalLength -gt 268435456) {
                Add-RegistryError "Package '$VersionPath' expands beyond the 256 MiB limit."
            }

            $manifestEntry = $archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -ceq 'plugin.json' } | Select-Object -First 1
            if ($null -eq $manifestEntry) {
                Add-RegistryError "Package '$VersionPath' does not contain root plugin.json."
                return
            }
            $reader = [System.IO.StreamReader]::new($manifestEntry.Open(), [System.Text.Encoding]::UTF8, $true)
            try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
            finally { $reader.Dispose() }

            $pluginId = [string](Get-PropertyValue -Object $Plugin -Name 'id')
            $versionText = [string](Get-PropertyValue -Object $Version -Name 'version')
            if ((Get-PropertyValue -Object $manifest -Name 'id') -cne $pluginId) {
                Add-RegistryError "Package '$VersionPath' plugin.json id does not match '$pluginId'."
            }
            if ((Get-PropertyValue -Object $manifest -Name 'version') -cne $versionText) {
                Add-RegistryError "Package '$VersionPath' plugin.json version does not match '$versionText'."
            }

            $compatibility = Get-PropertyValue -Object $Version -Name 'compatibility'
            $manifestComparisons = @{
                apiVersion = 'apiVersion'
                minHostVersion = 'minimumHostVersion'
                maxHostVersion = 'maximumHostVersion'
                targetFramework = 'targetFramework'
                platform = 'platform'
            }
            foreach ($manifestField in $manifestComparisons.Keys) {
                $registryField = $manifestComparisons[$manifestField]
                $manifestValue = Get-PropertyValue -Object $manifest -Name $manifestField
                $registryValue = Get-PropertyValue -Object $compatibility -Name $registryField
                if ($null -eq $manifestValue -and $null -eq $registryValue) { continue }
                if ([string]$manifestValue -cne [string]$registryValue) {
                    Add-RegistryError "Package '$VersionPath' plugin.json $manifestField does not match compatibility.$registryField."
                }
            }

            $manifestCapabilities = @((Get-PropertyValue -Object $manifest -Name 'capabilities') | Sort-Object)
            $registryCapabilities = @((Get-PropertyValue -Object $Version -Name 'capabilities') | Sort-Object)
            if (($manifestCapabilities -join "
") -cne ($registryCapabilities -join "
")) {
                Add-RegistryError "Package '$VersionPath' plugin.json capabilities do not match the version registry."
            }

            $assembly = [string](Get-PropertyValue -Object $manifest -Name 'assembly')
            if ([string]::IsNullOrWhiteSpace($assembly)) {
                Add-RegistryError "Package '$VersionPath' plugin.json must explicitly declare assembly."
            }
            elseif (-not $entryNames.Contains($assembly.Replace('\', '/'))) {
                Add-RegistryError "Package '$VersionPath' does not contain declared assembly '$assembly'."
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    catch {
        Add-RegistryError "Unable to verify package '$VersionPath': $($_.Exception.Message)"
    }
    finally {
        if (Test-Path -LiteralPath $tempDirectory) {
            Remove-Item -LiteralPath $tempDirectory -Recurse -Force
        }
    }
}

$publisherRoot = Join-Path $RepositoryRoot 'registry/publishers'
$pluginRoot = Join-Path $RepositoryRoot 'registry/plugins'
$publisherFiles = @(if (Test-Path -LiteralPath $publisherRoot) { Get-ChildItem -LiteralPath $publisherRoot -Filter '*.json' -File })
$pluginFiles = @(if (Test-Path -LiteralPath $pluginRoot) { Get-ChildItem -LiteralPath $pluginRoot -Filter 'plugin.json' -File -Recurse })

$publishers = @{}
foreach ($file in $publisherFiles) {
    Test-FileAgainstSchema -Path $file.FullName -SchemaPath (Join-Path $RepositoryRoot 'schemas/publisher.schema.json')
    $publisher = Read-JsonFile -Path $file.FullName
    if ($null -eq $publisher) { continue }
    Test-Publisher -Publisher $publisher -Path $file.FullName
    $publisherId = [string](Get-PropertyValue -Object $publisher -Name 'publisherId')
    if ($publishers.ContainsKey($publisherId)) {
        Add-RegistryError "Duplicate publisherId '$publisherId'."
    }
    else {
        $publishers[$publisherId] = $publisher
    }
}

$plugins = @{}
$versionRecords = [System.Collections.Generic.List[object]]::new()
foreach ($file in $pluginFiles) {
    Test-FileAgainstSchema -Path $file.FullName -SchemaPath (Join-Path $RepositoryRoot 'schemas/plugin.schema.json')
    $plugin = Read-JsonFile -Path $file.FullName
    if ($null -eq $plugin) { continue }
    Test-Plugin -Plugin $plugin -Path $file.FullName -Publishers $publishers
    $pluginId = [string](Get-PropertyValue -Object $plugin -Name 'id')
    if ($plugins.ContainsKey($pluginId)) {
        Add-RegistryError "Duplicate plugin id '$pluginId'."
        continue
    }
    $plugins[$pluginId] = $plugin

    $versionsByNumber = @{}
    $versionsDirectory = Join-Path (Split-Path -Parent $file.FullName) 'versions'
    $versionFiles = @(if (Test-Path -LiteralPath $versionsDirectory) { Get-ChildItem -LiteralPath $versionsDirectory -Filter '*.json' -File })
    foreach ($versionFile in $versionFiles) {
        Test-FileAgainstSchema -Path $versionFile.FullName -SchemaPath (Join-Path $RepositoryRoot 'schemas/plugin-version.schema.json')
        $version = Read-JsonFile -Path $versionFile.FullName
        if ($null -eq $version) { continue }
        Test-PluginVersion -Version $version -Path $versionFile.FullName -Plugin $plugin
        $versionText = [string](Get-PropertyValue -Object $version -Name 'version')
        if ($versionsByNumber.ContainsKey($versionText)) {
            Add-RegistryError "Plugin '$pluginId' contains duplicate version '$versionText'."
        }
        else {
            $versionsByNumber[$versionText] = $version
        }
        $versionRecords.Add([pscustomobject]@{
            RelativePath = Get-RelativePath -Path $versionFile.FullName
            FullPath = $versionFile.FullName
            Plugin = $plugin
            Version = $version
        })
    }

    $channels = Get-PropertyValue -Object $plugin -Name 'channels'
    if ($null -ne $channels) {
        foreach ($channelName in @('stable', 'beta')) {
            $channelVersion = Get-PropertyValue -Object $channels -Name $channelName
            if ($null -eq $channelVersion) { continue }
            if (-not $versionsByNumber.ContainsKey([string]$channelVersion)) {
                Add-RegistryError "Plugin '$pluginId' channel '$channelName' references missing version '$channelVersion'."
                continue
            }
            $referencedVersion = $versionsByNumber[[string]$channelVersion]
            if ((Get-PropertyValue -Object $referencedVersion -Name 'channel') -ne $channelName) {
                Add-RegistryError "Plugin '$pluginId' channel '$channelName' references a version from another channel."
            }
            if ((Get-PropertyValue -Object $referencedVersion -Name 'status') -ne 'active') {
                Add-RegistryError "Plugin '$pluginId' channel '$channelName' must reference an active version."
            }
        }
    }
}

$generatedSchemaPairs = @(
    @('registry/index.json', 'schemas/registry-index.schema.json'),
    @('registry/generated/community-catalog.json', 'schemas/community-catalog.schema.json')
)
foreach ($pair in $generatedSchemaPairs) {
    $generatedPath = Join-Path $RepositoryRoot $pair[0]
    $generatedSchema = Join-Path $RepositoryRoot $pair[1]
    if (Test-Path -LiteralPath $generatedPath -PathType Leaf) {
        Test-FileAgainstSchema -Path $generatedPath -SchemaPath $generatedSchema
    }
    else {
        Add-RegistryError "Generated registry file is missing: $generatedPath"
    }
}

$changedFiles = @(Get-ChangedRegistryFiles)
if ($PullRequestActorId -gt 0 -and $changedFiles.Count -gt 0) {
    foreach ($change in $changedFiles) {
        $relativePath = $change.Path.Replace('\', '/')
        $isRegistryJson = $relativePath -match '^registry/(publishers|plugins)/.+\.json$'
        if ($isRegistryJson -and ($change.Status.StartsWith('D') -or $change.Status.StartsWith('R'))) {
            Add-RegistryError "Registry history cannot be deleted or renamed: '$relativePath'. Use status metadata instead."
            continue
        }
        if ($relativePath -match '^registry/publishers/[^/]+\.json$') {
            $currentPath = Join-Path $RepositoryRoot $relativePath
            $currentPublisher = if (Test-Path -LiteralPath $currentPath) { Read-JsonFile -Path $currentPath } else { $null }
            if ($change.Status.StartsWith('A')) {
                if ($null -ne $currentPublisher) {
                    $identity = Get-PropertyValue -Object $currentPublisher -Name 'identity'
                    if ((Get-PropertyValue -Object $identity -Name 'userId') -ne $PullRequestActorId -or
                        (Get-PropertyValue -Object $identity -Name 'login') -ine $PullRequestActor) {
                        Add-RegistryError "New publisher registration must match pull-request author '$PullRequestActor' ($PullRequestActorId)."
                    }
                }
            }
            else {
                $basePublisher = Get-JsonAtRevision -Revision $BaseRevision -RelativePath $change.OldPath
                if ($null -ne $basePublisher) {
                    Test-ActorAuthorizedForPublisher -Publisher $basePublisher -Context "Publisher change '$relativePath'"
                }
            }
            continue
        }

        if ($relativePath -match '^registry/plugins/([^/]+)/') {
            $pluginDirectory = $Matches[1]
            $basePluginPath = "registry/plugins/$pluginDirectory/plugin.json"
            $publisherForOwnership = $null
            $currentPluginPath = Join-Path $RepositoryRoot $basePluginPath
            $currentPlugin = if (Test-Path -LiteralPath $currentPluginPath) { Read-JsonFile -Path $currentPluginPath } else { $null }
            $basePlugin = Get-JsonAtRevision -Revision $BaseRevision -RelativePath $basePluginPath
            if ($null -ne $basePlugin -and $null -ne $currentPlugin) {
                if ((Get-PropertyValue -Object $basePlugin -Name 'id') -cne (Get-PropertyValue -Object $currentPlugin -Name 'id')) {
                    Add-RegistryError "Published plugin ID cannot change in '$basePluginPath'."
                }
                if ((Get-PropertyValue -Object $basePlugin -Name 'publisherId') -cne (Get-PropertyValue -Object $currentPlugin -Name 'publisherId')) {
                    Add-RegistryError "Plugin ownership cannot be transferred through a normal registry PR: '$basePluginPath'."
                }
            }
            if ($null -ne $basePlugin) {
                $basePublisherId = [string](Get-PropertyValue -Object $basePlugin -Name 'publisherId')
                $publisherForOwnership = Get-JsonAtRevision -Revision $BaseRevision -RelativePath ("registry/publishers/github-" + $basePublisherId.Substring('github:'.Length) + '.json')
            }
            else {
                if ($null -ne $currentPlugin) {
                    $currentPublisherId = [string](Get-PropertyValue -Object $currentPlugin -Name 'publisherId')
                    if ($publishers.ContainsKey($currentPublisherId)) {
                        $publisherForOwnership = $publishers[$currentPublisherId]
                    }
                }
            }
            if ($null -ne $publisherForOwnership) {
                Test-ActorAuthorizedForPublisher -Publisher $publisherForOwnership -Context "Plugin change '$relativePath'"
            }
            else {
                Add-RegistryError "Cannot resolve publisher ownership for '$relativePath'."
            }

            if ($relativePath -match '/versions/[^/]+\.json$' -and -not $change.Status.StartsWith('A')) {
                $baseVersion = Get-JsonAtRevision -Revision $BaseRevision -RelativePath $change.OldPath
                $currentVersionPath = Join-Path $RepositoryRoot $relativePath
                $currentVersion = if (Test-Path -LiteralPath $currentVersionPath) { Read-JsonFile -Path $currentVersionPath } else { $null }
                if ($null -ne $baseVersion -and $null -ne $currentVersion -and
                    (Get-ImmutableVersionFingerprint -Version $baseVersion) -cne (Get-ImmutableVersionFingerprint -Version $currentVersion)) {
                    Add-RegistryError "Published version '$relativePath' changed immutable fields. Publish a new version instead."
                }
            }
        }
    }
}

if ($VerifyPackages) {
    $changedVersionPaths = @(
        $changedFiles |
            Where-Object { $_.Path.Replace('\', '/') -match '^registry/plugins/[^/]+/versions/[^/]+\.json$' } |
            ForEach-Object { $_.Path.Replace('\', '/') }
    )
    $recordsToVerify = if ($changedVersionPaths.Count -gt 0) {
        @($versionRecords | Where-Object { $_.RelativePath -in $changedVersionPaths -and (Get-PropertyValue -Object $_.Version -Name 'status') -eq 'active' })
    }
    elseif ([string]::IsNullOrWhiteSpace($BaseRevision)) {
        @($versionRecords | Where-Object { (Get-PropertyValue -Object $_.Version -Name 'status') -eq 'active' })
    }
    else {
        @()
    }

    foreach ($record in $recordsToVerify) {
        Test-Package -Version $record.Version -Plugin $record.Plugin -VersionPath $record.RelativePath
    }
}

foreach ($warning in $script:Warnings) {
    Write-Warning $warning
}
if ($script:Errors.Count -gt 0) {
    foreach ($validationError in $script:Errors) {
        Write-Error $validationError -ErrorAction Continue
    }
    throw "Community registry validation failed with $($script:Errors.Count) error(s)."
}

Write-Host "Community registry validation passed: $($publishers.Count) publisher(s), $($plugins.Count) plugin(s), $($versionRecords.Count) version(s)."
