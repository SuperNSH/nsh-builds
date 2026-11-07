# Installs NSH on Windows, x64 or Arm64.
#
#   irm https://raw.githubusercontent.com/SuperNSH/nsh-builds/master/install.ps1 | iex
#
# x64 gets NSH's own release (longbridge/nsh); Arm64 gets this repository's
# build of the same release.
#
# $env:NSH_VERSION      a release tag such as v0.4.0 (default: NSH's latest release)
# $env:NSH_INSTALL_DIR  where the distribution goes (default: %LOCALAPPDATA%\nsh)
#
# Its bin directory is added to the user's PATH. Running the script again
# updates it. Works with Windows PowerShell 5.1 and PowerShell 7.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$upstream = 'longbridge/nsh'
$builds = 'SuperNSH/nsh-builds'
$dir = if ($env:NSH_INSTALL_DIR) { $env:NSH_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'nsh' }
$version = if ($env:NSH_VERSION) { $env:NSH_VERSION } else { 'latest' }

# Windows PowerShell 5.1 may not offer TLS 1.2 by default.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($arch) {
    'AMD64' { $platform = 'windows-x86_64'; $repository = $upstream }
    'ARM64' { $platform = 'windows-arm64'; $repository = $builds }
    default { throw "nsh: no NSH build for Windows $arch" }
}

# Both repositories name releases by NSH's tag, so resolve "latest" from NSH itself.
if ($version -eq 'latest') {
    $release = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$upstream/releases/latest"
    $version = $release.tag_name
    if (-not $version) { throw "nsh: could not find NSH's latest release" }
}

$asset = "nsh-$platform.zip"
$url = "https://github.com/$repository/releases/download/$version/$asset"

$work = Join-Path ([IO.Path]::GetTempPath()) ("nsh-" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $zip = Join-Path $work $asset
    Write-Host "Downloading $url"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
    } catch {
        throw "nsh: no $asset for $version yet: $url"
    }
    # GitHub serves it as application/octet-stream: bytes in PowerShell 5.1.
    $sum = (Invoke-WebRequest -UseBasicParsing -Uri "$url.sha256").Content
    if ($sum -is [byte[]]) { $sum = [Text.Encoding]::ASCII.GetString($sum) }
    $expected = ($sum.Trim() -split '\s+')[0]
    $actual = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash
    if ($actual -ne $expected) {
        throw "nsh: the checksum of $asset does not match"
    }

    Expand-Archive -Path $zip -DestinationPath $work
    $extracted = Join-Path $work 'nsh'
    if (-not (Test-Path (Join-Path $extracted 'bin\nsh.exe'))) {
        throw "nsh: $asset holds no nsh\bin\nsh.exe"
    }

    # Replace the whole directory: runtimes of an older release must not stay.
    $parent = Split-Path -Parent $dir
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
    if (Test-Path $dir) {
        try {
            Remove-Item -Recurse -Force $dir
        } catch {
            throw "nsh: cannot replace $dir (is nsh or one of its hosts running?): $_"
        }
    }
    Move-Item -Path $extracted -Destination $dir
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

$bin = Join-Path $dir 'bin'
$installed = & (Join-Path $bin 'nsh.exe') --version
Write-Host "Installed $installed to $dir"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = if ($userPath) { $userPath -split ';' | Where-Object { $_ } } else { @() }
if ($entries -notcontains $bin) {
    [Environment]::SetEnvironmentVariable('Path', (@($entries) + $bin) -join ';', 'User')
    $env:Path = "$env:Path;$bin"
    Write-Host "Added $bin to your PATH; open a new terminal to use nsh there."
}
