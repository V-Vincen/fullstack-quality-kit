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
$RuleSource = Join-Path $RepoRoot 'rules\global-agents.block.md'
$MarkerStart = '<!-- fullstack-quality-kit:begin -->'
$MarkerEnd = '<!-- fullstack-quality-kit:end -->'

function Get-DefaultCodexHome {
    if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return (Join-Path $HOME '.codex')
    }
    return $env:CODEX_HOME
}

function Show-Usage {
    Write-Output '用法：.\scripts\install-global.ps1 [-Yes] [-CodexHomePath <Codex 全局目录>]'
    Write-Output ('默认目录：{0}' -f (Get-DefaultCodexHome))
}

function Get-SourceFiles {
    param([string]$SourceDir)
    @(Get-ChildItem -LiteralPath $SourceDir -File -Recurse | Where-Object Name -ne '.DS_Store')
}

function Get-RelativePath {
    param(
        [string]$SourceDir,
        [System.IO.FileInfo]$SourceFile
    )
    $SourceRoot = $SourceDir.TrimEnd([char[]]"\/")
    $SourceFile.FullName.Substring($SourceRoot.Length).TrimStart([char[]]"\/")
}

function Test-SameFile {
    param(
        [string]$SourceFile,
        [string]$TargetFile
    )
    $SourceHash = (Get-FileHash -LiteralPath $SourceFile -Algorithm SHA256).Hash
    $TargetHash = (Get-FileHash -LiteralPath $TargetFile -Algorithm SHA256).Hash
    return $SourceHash -eq $TargetHash
}

function Test-PreflightTree {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )
    foreach ($SourceFile in Get-SourceFiles $SourceDir) {
        $TargetFile = Join-Path $TargetDir (Get-RelativePath $SourceDir $SourceFile)
        if (Test-Path -LiteralPath $TargetFile) {
            if ((Test-Path -LiteralPath $TargetFile -PathType Container) -or
                -not (Test-SameFile $SourceFile.FullName $TargetFile)) {
                throw ('冲突：目标文件已存在且内容不同：{0}' -f $TargetFile)
            }
        }
    }
}

function Test-SameLines {
    param(
        [object[]]$Left,
        [object[]]$Right
    )
    if ($Left.Count -ne $Right.Count) {
        return $false
    }
    for ($Index = 0; $Index -lt $Left.Count; $Index++) {
        if ([string]$Left[$Index] -cne [string]$Right[$Index]) {
            return $false
        }
    }
    return $true
}

function Get-ManagedBlock {
    param([object[]]$Lines)
    $StartIndexes = @(
        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ([string]$Lines[$Index] -ceq $MarkerStart) {
                $Index
            }
        }
    )
    if ($StartIndexes.Count -eq 0) {
        return $null
    }
    if ($StartIndexes.Count -ne 1) {
        throw '失败：全局 AGENTS.md 包含多个 fullstack-quality-kit 管理区块。'
    }
    $StartIndex = $StartIndexes[0]
    $EndIndex = -1
    for ($Index = $StartIndex + 1; $Index -lt $Lines.Count; $Index++) {
        if ([string]$Lines[$Index] -ceq $MarkerEnd) {
            $EndIndex = $Index
            break
        }
    }
    if ($EndIndex -lt 0) {
        throw '失败：全局 AGENTS.md 的管理区块不完整。'
    }
    return @($Lines[$StartIndex..$EndIndex])
}

function Copy-Tree {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [System.Collections.Generic.List[string]]$CreatedFiles
    )
    $Copied = 0
    $Skipped = 0
    foreach ($SourceFile in Get-SourceFiles $SourceDir) {
        $TargetFile = Join-Path $TargetDir (Get-RelativePath $SourceDir $SourceFile)
        if (Test-Path -LiteralPath $TargetFile) {
            $Skipped++
            continue
        }
        $TargetParent = Split-Path -Parent $TargetFile
        New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null
        Copy-Item -LiteralPath $SourceFile.FullName -Destination $TargetFile
        $CreatedFiles.Add($TargetFile)
        $Copied++
    }
    Write-Output ('已处理 {0}：新增 {1} 个，已存在且一致 {2} 个。' -f $SourceDir, $Copied, $Skipped)
}

function Backup-GlobalAgents {
    param([string]$AgentsPath)
    if (-not $script:AgentsNeedsChange -or -not (Test-Path -LiteralPath $AgentsPath -PathType Leaf)) {
        return
    }
    $BackupDir = Join-Path $CodexHomePath 'backups'
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupPath = Join-Path $BackupDir ('fullstack-quality-kit--AGENTS.md--{0}-before-global-install.bak' -f $Timestamp)
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    if (Test-Path -LiteralPath $BackupPath) {
        throw ('失败：备份文件已存在：{0}' -f $BackupPath)
    }
    Copy-Item -LiteralPath $AgentsPath -Destination $BackupPath
    Write-Output ('已备份全局规则：{0}' -f $BackupPath)
}

if ($Help) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($CodexHomePath)) {
    $CodexHomePath = Get-DefaultCodexHome
}
if (-not (Test-Path -LiteralPath $SourceSkills -PathType Container)) {
    throw '失败：缺少源 skill 目录。'
}
if (-not (Test-Path -LiteralPath $SourceChecklists -PathType Container)) {
    throw '失败：缺少源清单目录。'
}
if (-not (Test-Path -LiteralPath $RuleSource -PathType Leaf)) {
    throw '失败：缺少全局规则片段。'
}

$TargetSkills = Join-Path $CodexHomePath 'skills\fullstack-review'
$TargetChecklists = Join-Path $CodexHomePath 'checklists\fullstack-quality-kit'
$GlobalAgents = Join-Path $CodexHomePath 'AGENTS.md'
$Manifest = Join-Path $TargetChecklists '.fullstack-quality-kit.manifest'
$DesiredBlock = @($MarkerStart) + @(Get-Content -LiteralPath $RuleSource) + @($MarkerEnd)

Test-PreflightTree $SourceSkills $TargetSkills
Test-PreflightTree $SourceChecklists $TargetChecklists
if (Test-Path -LiteralPath $Manifest) {
    if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
        throw ('失败：安装清单路径不是普通文件：{0}' -f $Manifest)
    }
}

$AgentsNeedsChange = $false
if (Test-Path -LiteralPath $GlobalAgents) {
    if (-not (Test-Path -LiteralPath $GlobalAgents -PathType Leaf)) {
        throw '失败：全局 AGENTS.md 不是普通文件。'
    }
    $CurrentLines = @(Get-Content -LiteralPath $GlobalAgents)
    $CurrentBlock = Get-ManagedBlock $CurrentLines
    if ($null -ne $CurrentBlock) {
        if (-not (Test-SameLines $DesiredBlock $CurrentBlock)) {
            throw '冲突：全局 AGENTS.md 已有不同的 fullstack-quality-kit 管理区块。'
        }
    } else {
        $AgentsNeedsChange = $true
    }
} else {
    $AgentsNeedsChange = $true
}

if (-not $Yes) {
    $Answer = Read-Host ('将安装到 {0}，并可能更新 {1}。继续？ [y/N]' -f $CodexHomePath, $GlobalAgents)
    if ($Answer -notmatch '^[yY]$') {
        Write-Output '已取消。'
        exit 0
    }
}

$CreatedFiles = New-Object 'System.Collections.Generic.List[string]'
Backup-GlobalAgents $GlobalAgents
New-Item -ItemType Directory -Path $CodexHomePath, $TargetSkills, $TargetChecklists -Force | Out-Null
Copy-Tree $SourceSkills $TargetSkills $CreatedFiles
Copy-Tree $SourceChecklists $TargetChecklists $CreatedFiles

if ($AgentsNeedsChange) {
    if (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) {
        Add-Content -LiteralPath $GlobalAgents -Value @('') -Encoding UTF8
        Add-Content -LiteralPath $GlobalAgents -Value $DesiredBlock -Encoding UTF8
    } else {
        Set-Content -LiteralPath $GlobalAgents -Value $DesiredBlock -Encoding UTF8
    }
}

if ($CreatedFiles.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
        Set-Content -LiteralPath $Manifest -Value '# fullstack-quality-kit installed files' -Encoding UTF8
    }
    $ExistingManifest = @(Get-Content -LiteralPath $Manifest)
    foreach ($CreatedFile in $CreatedFiles) {
        if ($ExistingManifest -notcontains $CreatedFile) {
            Add-Content -LiteralPath $Manifest -Value $CreatedFile -Encoding UTF8
            $ExistingManifest += $CreatedFile
        }
    }
}

Write-Output ('全局安装完成：{0}' -f $CodexHomePath)
