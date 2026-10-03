[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProjectDir,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptDir
$SourceSkills = Join-Path $RepoRoot '.codex\skills'
$SourceChecklists = Join-Path $RepoRoot '.codex\checklists'

function Show-Usage {
    Write-Output '用法：.\scripts\install-project.ps1 <业务项目目录>'
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

function Copy-Tree {
    param(
        [string]$SourceDir,
        [string]$TargetDir
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
        $Copied++
    }
    Write-Output ('已处理 {0}：新增 {1} 个，已存在且一致 {2} 个。' -f $SourceDir, $Copied, $Skipped)
}

if ($Help) {
    Show-Usage
    exit 0
}
if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    Show-Usage
    exit 2
}
if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
    throw ('失败：业务项目目录不存在：{0}' -f $ProjectDir)
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectDir).Path
$TargetSkills = Join-Path $ProjectRoot '.codex\skills'
$TargetChecklists = Join-Path $ProjectRoot '.codex\checklists'

Test-PreflightTree $SourceSkills $TargetSkills
Test-PreflightTree $SourceChecklists $TargetChecklists

New-Item -ItemType Directory -Path $TargetSkills, $TargetChecklists -Force | Out-Null
Copy-Tree $SourceSkills $TargetSkills
Copy-Tree $SourceChecklists $TargetChecklists
Write-Output ('项目级安装完成：{0}' -f $ProjectRoot)
