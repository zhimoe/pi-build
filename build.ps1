# Assemble a Windows x64 runtime from pinned published packages and verify relocation.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$systemPath = $env:PATH
$root = $PSScriptRoot
$out = Join-Path $root 'out'
$downloads = Join-Path $root 'downloads'
$bundle = Join-Path $out 'pi-offline'
if (Test-Path $out) { throw 'out already exists; use a clean checkout for each build.' }
New-Item -ItemType Directory -Force $bundle, $downloads | Out-Null

function Get-VerifiedFile($Url, $Name, $Sha256) {
    $path = Join-Path $downloads $Name
    Invoke-WebRequest $Url -OutFile $path
    if ((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Sha256) {
        throw "Checksum mismatch: $Name"
    }
    return $path
}

$node = Get-VerifiedFile 'https://nodejs.org/dist/v22.23.4/node-v22.23.4-win-x64.zip' 'node.zip' 'cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20'
Expand-Archive $node -DestinationPath $downloads
Move-Item "$downloads/node-v22.23.4-win-x64" "$bundle/node"
$env:PATH = "$bundle/node;$env:PATH"

$app = New-Item -ItemType Directory "$bundle/app"
'{"name":"pi-offline-runtime","version":"1.0.0","private":true,"dependencies":{"@earendil-works/pi-coding-agent":"1.5.0"}}' | Set-Content "$app/package.json" -Encoding utf8
Push-Location $app
try {
    npm.cmd install --ignore-scripts --omit=dev --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
} finally { Pop-Location }

$git = Get-VerifiedFile 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/PortableGit-2.56.0.4-64-bit.7z.exe' 'git.7z.exe' 'b1f3e52216e2ed6882d1bebfd4d3fdf319bec40d2edbbf9fd26ec4fd3fce7ed1'
& 7z x $git "-o$bundle/git" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Git extraction failed' }
$rg = Get-VerifiedFile 'https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-pc-windows-msvc.zip' 'rg.zip' '71b2fef860abe467217a538ff31de02f5258807c0129f771846f87bd029aafc5'
$fd = Get-VerifiedFile 'https://github.com/sharkdp/fd/releases/download/v10.5.2/fd-v10.5.2-x86_64-pc-windows-msvc.zip' 'fd.zip' '7edac75ef96b7e9a01ebb251a21ee86ea365a09adcfb865f1ec3346a906153b6'
Expand-Archive $rg "$bundle/tools/rg"
Expand-Archive $fd "$bundle/tools/fd"
$rgDir = (Get-ChildItem "$bundle/tools/rg" -Filter rg.exe -Recurse).Directory.FullName
$fdDir = (Get-ChildItem "$bundle/tools/fd" -Filter fd.exe -Recurse).Directory.FullName
$rgRelative = [IO.Path]::GetRelativePath($bundle, $rgDir)
$fdRelative = [IO.Path]::GetRelativePath($bundle, $fdDir)

@"
@echo off
setlocal
set "PATH=%~dp0node;%~dp0git\cmd;%~dp0git\bin;%~dp0$rgRelative;%~dp0$fdRelative;%PATH%"
set "PI_OFFLINE=1"
"%~dp0node\node.exe" "%~dp0app\node_modules\@earendil-works\pi-coding-agent\dist\bundle\cli.js" %*
exit /b %errorlevel%
"@ | Set-Content "$bundle/pi.cmd" -Encoding ascii
Copy-Item "$root/README.md" "$bundle/README.md"
Copy-Item "$root/models.example.json" "$bundle/models.example.json"

# Change the directory name and remove hosted tool paths to catch accidental runner dependencies.
$relocated = Join-Path $out 'pi offline relocated'
Move-Item $bundle $relocated
$savedPath = $env:PATH
try {
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
    $env:PI_OFFLINE = '1'
    & "$relocated/pi.cmd" --version
    if ($LASTEXITCODE -ne 0) { throw 'Relocated Pi failed' }
    & "$relocated/pi.cmd" --help
    if ($LASTEXITCODE -ne 0) { throw 'Pi help failed' }
    & "$relocated/node/node.exe" -p 'process.platform + " " + process.arch'
    if ($LASTEXITCODE -ne 0) { throw 'Node failed' }
    & "$relocated/git/bin/bash.exe" -c 'git --version && printf "Bash OK\n"'
    if ($LASTEXITCODE -ne 0) { throw 'Portable Git/Bash failed' }
    & "$relocated/$rgRelative/rg.exe" --version
    if ($LASTEXITCODE -ne 0) { throw 'rg failed' }
    & "$relocated/$fdRelative/fd.exe" --version
    if ($LASTEXITCODE -ne 0) { throw 'fd failed' }
} finally { $env:PATH = $savedPath }
Move-Item $relocated $bundle

# The lite package shares the installed dependencies but uses the target's tools.
$lite = Join-Path $out 'pi-offline-lite'
New-Item -ItemType Directory $lite | Out-Null
Copy-Item "$bundle/app" "$lite/app" -Recurse
Copy-Item "$root/README.md", "$root/models.example.json" $lite
@'
@echo off
setlocal
set "PI_OFFLINE=1"
node.exe "%~dp0app\node_modules\@earendil-works\pi-coding-agent\dist\bundle\cli.js" %*
exit /b %errorlevel%
'@ | Set-Content "$lite/pi.cmd" -Encoding ascii
$liteRelocated = Join-Path $out 'pi lite relocated'
Move-Item $lite $liteRelocated
try {
    $env:PATH = $systemPath
    & "$liteRelocated/pi.cmd" --version
    if ($LASTEXITCODE -ne 0) { throw 'Relocated lite Pi failed with system Node' }
    & "$liteRelocated/pi.cmd" --help
    if ($LASTEXITCODE -ne 0) { throw 'Lite Pi help failed with system Node' }
} finally { $env:PATH = $savedPath }
Move-Item $liteRelocated $lite
Push-Location $out
try {
    $checksums = foreach ($variant in @(
        @{ Archive = 'pi-1.5.0-windows-x64.zip'; Directory = 'pi-offline' },
        @{ Archive = 'pi-1.5.0-windows-x64-lite.zip'; Directory = 'pi-offline-lite' }
    )) {
        & 7z a -tzip -mx=5 $variant.Archive $variant.Directory | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Archive creation failed: $($variant.Archive)" }
        $hash = (Get-FileHash $variant.Archive -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($variant.Archive)"
    }
    $checksums | Set-Content 'SHA256SUMS.txt' -Encoding ascii
} finally { Pop-Location }
