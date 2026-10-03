[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProjectDir,
    [Parameter(Position = 1)]
    [string]$CodexHomePath,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptDir
$SourceSkills = Join-Path $RepoRoot '.codex\skills'
$SourceChecklists = Join-Path $RepoRoot '.codex\checklists'

function Show-Usage {
    Write-Output '用法：.\scripts\status.ps1 [业务项目目录] [Codex 全局目录]'
}

function Get-DefaultCodexHome {
    if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return (Join-Path $HOME '.codex')
    }
    return $env:CODEX_HOME
}

function Get-FileCount {
    param(
        [string]$Directory,
        [string]$Filter
    )
    @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Filter $Filter -ErrorAction SilentlyContinue).Count
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

function Report-Tree {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )
    if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
        Write-Output ('  未安装：{0}' -f $TargetDir)
        return
    }
    $Missing = 0
    $Conflict = 0
    foreach ($SourceFile in Get-SourceFiles $SourceDir) {
        $TargetFile = Join-Path $TargetDir (Get-RelativePath $SourceDir $SourceFile)
        if (-not (Test-Path -LiteralPath $TargetFile -PathType Leaf)) {
            $Missing++
        } elseif (-not (Test-SameFile $SourceFile.FullName $TargetFile)) {
            $Conflict++
        }
    }
    if ($Missing -eq 0 -and $Conflict -eq 0) {
        Write-Output ('  已安装且一致：{0}' -f $TargetDir)
    } else {
        Write-Output ('  状态异常：{0}；缺失 {1} 个，冲突 {2} 个' -f $TargetDir, $Missing, $Conflict)
    }
}

if ($Help) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    $ProjectDir = (Get-Location).Path
}
if ([string]::IsNullOrWhiteSpace($CodexHomePath)) {
    $CodexHomePath = Get-DefaultCodexHome
}

Write-Output 'fullstack-quality-kit 状态'
Write-Output ('仓库：{0}' -f $RepoRoot)
Write-Output ('源 skill：{0} 个' -f (Get-FileCount $SourceSkills 'SKILL.md'))
Write-Output ('源清单：{0} 个' -f (Get-FileCount $SourceChecklists '*.md'))
Write-Output ('项目级安装：{0}' -f $ProjectDir)
if (Test-Path -LiteralPath $ProjectDir -PathType Container) {
    Report-Tree $SourceSkills (Join-Path $ProjectDir '.codex\skills')
    Report-Tree $SourceChecklists (Join-Path $ProjectDir '.codex\checklists')
} else {
    Write-Output '  业务项目目录不存在'
}

Write-Output ('全局安装：{0}' -f $CodexHomePath)
Report-Tree $SourceSkills (Join-Path $CodexHomePath 'skills\fullstack-review')
Report-Tree $SourceChecklists (Join-Path $CodexHomePath 'checklists\fullstack-quality-kit')
$Manifest = Join-Path $CodexHomePath 'checklists\fullstack-quality-kit\.fullstack-quality-kit.manifest'
if (Test-Path -LiteralPath $Manifest -PathType Leaf) {
    Write-Output '  存在全局安装清单'
} else {
    Write-Output '  未发现全局安装清单'
}
$GlobalAgents = Join-Path $CodexHomePath 'AGENTS.md'
if ((Test-Path -LiteralPath $GlobalAgents -PathType Leaf) -and
    (Select-String -LiteralPath $GlobalAgents -Pattern '<!-- fullstack-quality-kit:begin -->' -SimpleMatch -Quiet)) {
    Write-Output '  已合并全局规则管理区块'
} else {
    Write-Output '  未合并全局规则管理区块'
}
