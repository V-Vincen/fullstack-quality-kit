[CmdletBinding()]
param(
    [switch]$Yes,
    [string]$CodexHomePath,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptDir
$SourceSkills = Join-Path $RepoRoot '.codex\skills'
$SourceChecklists = Join-Path $RepoRoot '.codex\checklists'
$MarkerStart = '<!-- fullstack-quality-kit:begin -->'
$MarkerEnd = '<!-- fullstack-quality-kit:end -->'

function Get-DefaultCodexHome {
    if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return (Join-Path $HOME '.codex')
    }
    return $env:CODEX_HOME
}

function Show-Usage {
    Write-Output '用法：.\scripts\uninstall-global.ps1 [-Yes] [-CodexHomePath <Codex 全局目录>]'
    Write-Output ('默认目录：{0}' -f (Get-DefaultCodexHome))
}

function Get-ManagedBlockIndexes {
    param([object[]]$Lines)
    $StartIndex = -1
    $EndIndex = -1
    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        if ([string]$Lines[$Index] -ceq $MarkerStart) {
            if ($StartIndex -ge 0) {
                throw '失败：全局 AGENTS.md 包含多个 fullstack-quality-kit 管理区块。'
            }
            $StartIndex = $Index
        }
    }
    if ($StartIndex -lt 0) {
        return $null
    }
    for ($Index = $StartIndex + 1; $Index -lt $Lines.Count; $Index++) {
        if ([string]$Lines[$Index] -ceq $MarkerEnd) {
            $EndIndex = $Index
            break
        }
    }
    if ($EndIndex -lt 0) {
        throw '失败：全局 AGENTS.md 的管理区块不完整。'
    }
    return @($StartIndex, $EndIndex)
}

function Backup-GlobalAgents {
    param(
        [string]$AgentsPath,
        [string]$BackupRoot
    )
    $BackupDir = Join-Path $BackupRoot 'backups'
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupPath = Join-Path $BackupDir ('fullstack-quality-kit--AGENTS.md--{0}-before-global-uninstall.bak' -f $Timestamp)
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    if (Test-Path -LiteralPath $BackupPath) {
        throw ('失败：备份文件已存在：{0}' -f $BackupPath)
    }
    Copy-Item -LiteralPath $AgentsPath -Destination $BackupPath
    Write-Output ('已备份全局规则：{0}' -f $BackupPath)
}

function Test-ManagedPath {
    param(
        [string]$Path,
        [string]$Root
    )
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $FullRoot = ([System.IO.Path]::GetFullPath($Root)).TrimEnd([char[]]"\/") + [System.IO.Path]::DirectorySeparatorChar
    return $FullPath.StartsWith($FullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Remove-SourceEmptyDirs {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot
    )
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        return
    }
    $SourceRootNormalized = $SourceRoot.TrimEnd([char[]]"\/")
    foreach ($SourceDir in @(Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse | Sort-Object FullName -Descending)) {
        $RelativePath = $SourceDir.FullName.Substring($SourceRootNormalized.Length).TrimStart([char[]]"\/")
        $TargetDir = Join-Path $TargetRoot $RelativePath
        if (Test-Path -LiteralPath $TargetDir -PathType Container) {
            try {
                Remove-Item -LiteralPath $TargetDir -Force -ErrorAction Stop
            } catch {
            }
        }
    }
    if (Test-Path -LiteralPath $TargetRoot -PathType Container) {
        try {
            Remove-Item -LiteralPath $TargetRoot -Force -ErrorAction Stop
        } catch {
        }
    }
}

if ($Help) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($CodexHomePath)) {
    $CodexHomePath = Get-DefaultCodexHome
}

$TargetSkills = Join-Path $CodexHomePath 'skills\fullstack-review'
$TargetChecklists = Join-Path $CodexHomePath 'checklists\fullstack-quality-kit'
$GlobalAgents = Join-Path $CodexHomePath 'AGENTS.md'
$Manifest = Join-Path $TargetChecklists '.fullstack-quality-kit.manifest'

$HasManifest = Test-Path -LiteralPath $Manifest -PathType Leaf
$BlockIndexes = $null
$HasBlock = $false
if (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) {
    $GlobalLines = @(Get-Content -LiteralPath $GlobalAgents)
    $BlockIndexes = Get-ManagedBlockIndexes $GlobalLines
    $HasBlock = $null -ne $BlockIndexes
}
if (-not $HasManifest -and -not $HasBlock) {
    Write-Output '没有找到 fullstack-quality-kit 的全局安装记录。'
    exit 0
}

if (-not $Yes) {
    $Answer = Read-Host ('将卸载 {0} 中由 fullstack-quality-kit 管理的内容。继续？ [y/N]' -f $CodexHomePath)
    if ($Answer -notmatch '^[yY]$') {
        Write-Output '已取消。'
        exit 0
    }
}

if ($HasBlock) {
    Backup-GlobalAgents $GlobalAgents $CodexHomePath
}

if ($HasManifest) {
    $ManagedFiles = @(
        Get-Content -LiteralPath $Manifest |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith('#') }
    )
    foreach ($ManagedFile in $ManagedFiles) {
        if (-not (Test-ManagedPath $ManagedFile $TargetSkills) -and
            -not (Test-ManagedPath $ManagedFile $TargetChecklists)) {
            throw ('失败：安装清单包含受保护范围外的路径：{0}' -f $ManagedFile)
        }
        if (Test-Path -LiteralPath $ManagedFile -PathType Container) {
            throw ('失败：安装清单包含目录路径：{0}' -f $ManagedFile)
        }
    }
    foreach ($ManagedFile in $ManagedFiles) {
        if (Test-Path -LiteralPath $ManagedFile) {
            Remove-Item -LiteralPath $ManagedFile -Force
        }
    }
    Remove-Item -LiteralPath $Manifest -Force
}

if ($HasBlock) {
    $GlobalLines = @(Get-Content -LiteralPath $GlobalAgents)
    $StartIndex = $BlockIndexes[0]
    $EndIndex = $BlockIndexes[1]
    $NewLines = New-Object System.Collections.Generic.List[string]
    for ($Index = 0; $Index -lt $GlobalLines.Count; $Index++) {
        if ($Index -lt $StartIndex -or $Index -gt $EndIndex) {
            $NewLines.Add([string]$GlobalLines[$Index])
        }
    }
    if ($NewLines.Count -eq 0) {
        [System.IO.File]::WriteAllText($GlobalAgents, '')
    } else {
        $NewLineArray = $NewLines.ToArray()
        Set-Content -LiteralPath $GlobalAgents -Value $NewLineArray -Encoding UTF8
    }
}

Remove-SourceEmptyDirs $SourceSkills $TargetSkills
Remove-SourceEmptyDirs $SourceChecklists $TargetChecklists
Write-Output ('全局卸载完成：{0}' -f $CodexHomePath)
