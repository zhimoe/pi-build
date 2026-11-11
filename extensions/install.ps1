param(
    [string]$AgentDir = (Join-Path $env:USERPROFILE '.pi\agent')
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$sourceNpm = Join-Path $root 'npm'
$newSources = @(
    'npm:context-mode@2.1.7',
    'npm:pi-web-access@0.47.0',
    'npm:pi-smart-fetch@0.3.23'
)

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

if (-not (Test-Path (Join-Path $sourceNpm 'node_modules'))) {
    throw "安装文件不完整：$sourceNpm\node_modules 不存在。请完整解压压缩包后再运行。"
}

Write-Host "安装 Pi 扩展到 $AgentDir ..."
New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null
$destNpm = Join-Path $AgentDir 'npm'
$destNodeModules = Join-Path $destNpm 'node_modules'
New-Item -ItemType Directory -Force -Path $destNodeModules | Out-Null

# 先删除旧版本的三个扩展目录，再合并 node_modules，避免残留旧文件。
foreach ($name in @('context-mode', 'pi-web-access', 'pi-smart-fetch')) {
    $old = Join-Path $destNodeModules $name
    if (Test-Path $old) { Remove-Item $old -Recurse -Force }
}
# 合并 node_modules。Robocopy 比 Copy-Item 更适合覆盖合并已有目录。
& robocopy (Join-Path $sourceNpm 'node_modules') $destNodeModules /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "复制 node_modules 失败（robocopy exit $LASTEXITCODE）。"
}

# 合并 package.json 的 dependencies，保留用户已有的其他扩展。
$srcPkgPath = Join-Path $sourceNpm 'package.json'
$dstPkgPath = Join-Path $destNpm 'package.json'
$srcPkg = Get-Content -Raw -Encoding UTF8 $srcPkgPath | ConvertFrom-Json
if (Test-Path $dstPkgPath) {
    Copy-Item $dstPkgPath "$dstPkgPath.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
    $dstPkg = Get-Content -Raw -Encoding UTF8 $dstPkgPath | ConvertFrom-Json
} else {
    $dstPkg = [pscustomobject]@{ name = 'pi-extensions'; private = $true }
}
$deps = [ordered]@{}
if ($dstPkg.PSObject.Properties.Name -contains 'dependencies' -and $null -ne $dstPkg.dependencies) {
    foreach ($prop in $dstPkg.dependencies.PSObject.Properties) { $deps[$prop.Name] = $prop.Value }
}
foreach ($prop in $srcPkg.dependencies.PSObject.Properties) { $deps[$prop.Name] = $prop.Value }
$depsObject = [pscustomobject]$deps
if ($dstPkg.PSObject.Properties.Name -contains 'dependencies') {
    $dstPkg.dependencies = $depsObject
} else {
    $dstPkg | Add-Member -NotePropertyName dependencies -NotePropertyValue $depsObject
}
Write-Utf8NoBom $dstPkgPath (ConvertTo-Json -InputObject $dstPkg -Depth 20)

# 没有 lockfile 时补一份，已有则保留用户的。
if (-not (Test-Path (Join-Path $destNpm 'package-lock.json'))) {
    Copy-Item (Join-Path $sourceNpm 'package-lock.json') $destNpm -Force
}

# 合并 settings.json 的 packages 数组。
$settingsPath = Join-Path $AgentDir 'settings.json'
$settings = $null
if (Test-Path $settingsPath) {
    Copy-Item $settingsPath "$settingsPath.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
    $raw = Get-Content -Raw -Encoding UTF8 $settingsPath
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $settings = $raw | ConvertFrom-Json
        } catch {
            throw "settings.json 不是有效的 JSON，已保留备份。请先手动修复：$settingsPath`n$_"
        }
    }
}
if ($null -eq $settings) { $settings = [pscustomobject]@{} }

$existing = @()
if ($settings.PSObject.Properties.Name -contains 'packages' -and $null -ne $settings.packages) {
    $existing = @($settings.packages)
}
$kept = New-Object System.Collections.Generic.List[object]
foreach ($entry in $existing) {
    $source = ''
    if ($entry -is [string]) {
        $source = $entry
    } elseif ($null -ne $entry.PSObject.Properties['source']) {
        $source = [string]$entry.PSObject.Properties['source'].Value
    }
    # 旧版本的同名扩展条目会被固定版本的条目替换。
    if ($source -match '^npm:(context-mode|pi-web-access|pi-smart-fetch)(@|$)') { continue }
    $kept.Add($entry)
}
foreach ($source in $newSources) { $kept.Add($source) }
$allPackages = [object[]]$kept.ToArray()
if ($settings.PSObject.Properties.Name -contains 'packages') {
    $settings.packages = $allPackages
} else {
    $settings | Add-Member -NotePropertyName packages -NotePropertyValue $allPackages
}
Write-Utf8NoBom $settingsPath (ConvertTo-Json -InputObject $settings -Depth 20)
Write-Host "已更新 $settingsPath"

Write-Host ''
Write-Host '完成。请完全退出并重新启动 Pi，然后执行：'
Write-Host '  pi.cmd list'
Write-Host '应看到三个 npm: 开头的包。'

$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
if ($null -eq $nodeCommand) { $nodeCommand = Get-Command node -ErrorAction SilentlyContinue }
if ($null -eq $nodeCommand) {
    Write-Warning '未找到 node。Pi 需要 Node 22.19+；context-mode 还需要 Node 24.15+ 和 Git Bash。'
} else {
    try {
        $nodeVersion = (& $nodeCommand.Path --version).Trim()
        $nodeParsed = [version]$nodeVersion.TrimStart('v')
        if ($nodeParsed -lt [version]'24.15.0') {
            Write-Warning "当前 Node $nodeVersion 低于 24.15.0。pi-web-access 和 pi-smart-fetch 可用，但 context-mode 将无法运行。"
        }
    } catch {
        Write-Warning "无法读取 Node 版本。context-mode 需要 Node 24.15.0 或更高版本。"
    }
}
