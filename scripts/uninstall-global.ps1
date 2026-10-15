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
$SourceSkillRoot = Join-Path $SourceSkills 'fullstack-review'
$SourceChecklists = Join-Path $RepoRoot '.codex\checklists'
$MarkerStart = '<!-- fullstack-quality-kit:begin -->'
$MarkerEnd = '<!-- fullstack-quality-kit:end -->'
$ManifestHeader = '# fullstack-quality-kit manifest v2'

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

function Get-FileHashValue {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-BlockHash {
    param([object[]]$Lines)
    $Text = ((@($Lines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine) + [Environment]::NewLine)
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $HashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($HashAlgorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $HashAlgorithm.Dispose()
    }
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

function Get-ManagedBlockIndexes {
    param([object[]]$Lines)
    $StartIndexes = @(
        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ([string]$Lines[$Index] -ceq $MarkerStart) {
                $Index
            }
        }
    )
    $EndIndexes = @(
        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ([string]$Lines[$Index] -ceq $MarkerEnd) {
                $Index
            }
        }
    )
    if ($StartIndexes.Count -eq 0 -and $EndIndexes.Count -eq 0) {
        return $null
    }
    if ($StartIndexes.Count -ne 1 -or $EndIndexes.Count -ne 1) {
        throw '失败：全局 AGENTS.md 的 fullstack-quality-kit 管理区块标记数量异常。'
    }
    $StartIndex = $StartIndexes[0]
    $EndIndex = $EndIndexes[0]
    if ($EndIndex -le $StartIndex) {
        throw '失败：全局 AGENTS.md 的管理区块不完整。'
    }
    return @($StartIndex, $EndIndex)
}

function Get-ManagedBlock {
    param([object[]]$Lines)
    $Indexes = Get-ManagedBlockIndexes $Lines
    if ($null -eq $Indexes) {
        return $null
    }
    return @($Lines[$Indexes[0]..$Indexes[1]])
}

function New-ManifestRecord {
    param(
        [string]$Kind,
        [string]$Path,
        [string]$Hash
    )
    [PSCustomObject]@{
        Kind = $Kind
        Path = [System.IO.Path]::GetFullPath($Path)
        Hash = $Hash.ToLowerInvariant()
    }
}

function Get-ManifestRecords {
    param(
        [string]$ManifestPath,
        [string]$TargetSkills,
        [string]$TargetChecklists,
        [string]$GlobalAgents
    )
    $Lines = @(Get-Content -LiteralPath $ManifestPath)
    if ($Lines.Count -eq 0 -or $Lines[0] -cne $ManifestHeader) {
        throw ('失败：安装清单不是 v2 格式：{0}' -f $ManifestPath)
    }
    $Records = New-Object 'System.Collections.Generic.List[object]'
    $BlockCount = 0
    foreach ($Line in @($Lines | Select-Object -Skip 1)) {
        if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#')) {
            continue
        }
        $Fields = $Line.Split([char[]]@([char]9))
        if ($Fields.Count -ne 3 -or
            [string]::IsNullOrWhiteSpace($Fields[0]) -or
            [string]::IsNullOrWhiteSpace($Fields[1]) -or
            $Fields[2] -notmatch '^[0-9a-fA-F]{64}$') {
            throw ('失败：安装清单格式无效：{0}' -f $ManifestPath)
        }
        $Kind = $Fields[0]
        $Path = $Fields[1]
        $Hash = $Fields[2]
        if ($Kind -ceq 'file') {
            if (-not (Test-ManagedPath $Path $TargetSkills) -and
                -not (Test-ManagedPath $Path $TargetChecklists)) {
                throw ('失败：安装清单包含受保护范围外的路径：{0}' -f $Path)
            }
        } elseif ($Kind -ceq 'agents-block') {
            if ([System.IO.Path]::GetFullPath($Path) -cne [System.IO.Path]::GetFullPath($GlobalAgents)) {
                throw ('失败：安装清单包含无效的全局规则路径：{0}' -f $Path)
            }
            $BlockCount++
            if ($BlockCount -gt 1) {
                throw '失败：安装清单包含多个全局规则记录。'
            }
        } else {
            throw ('失败：安装清单包含未知记录类型：{0}' -f $Kind)
        }
        $Records.Add((New-ManifestRecord $Kind $Path $Hash))
    }
    return $Records.ToArray()
}

function Write-Manifest {
    param(
        [string]$ManifestPath,
        [System.Collections.Generic.List[object]]$Records
    )
    $Lines = New-Object 'System.Collections.Generic.List[string]'
    $Lines.Add($ManifestHeader)
    foreach ($Record in $Records) {
        $Lines.Add(('{0}{1}{2}{1}{3}' -f $Record.Kind, [char]9, $Record.Path, $Record.Hash))
    }
    [System.IO.File]::WriteAllLines(
        $ManifestPath,
        [string[]]$Lines.ToArray(),
        [System.Text.UTF8Encoding]::new($false)
    )
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

if (Test-Path -LiteralPath $Manifest -and -not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
    throw ('失败：安装清单路径不是普通文件：{0}' -f $Manifest)
}
$HasManifest = Test-Path -LiteralPath $Manifest -PathType Leaf
$HasMarker = (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) -and
    (Select-String -LiteralPath $GlobalAgents -Pattern $MarkerStart -SimpleMatch -Quiet)

if (-not $HasManifest -and -not $HasMarker) {
    Write-Output '没有找到 fullstack-quality-kit 的全局安装记录。'
    exit 0
}
if (-not $HasManifest) {
    throw '失败：检测到未验证的旧版全局规则管理区块；为保护用户内容，未执行卸载。'
}
$ManifestFirstLine = @(Get-Content -LiteralPath $Manifest -TotalCount 1)
if ($ManifestFirstLine.Count -eq 0 -or $ManifestFirstLine[0] -cne $ManifestHeader) {
    throw '失败：检测到旧版安装清单；请先重新执行 install-global 升级清单，再执行卸载。'
}

$Records = New-Object 'System.Collections.Generic.List[object]'
foreach ($Record in @(Get-ManifestRecords $Manifest $TargetSkills $TargetChecklists $GlobalAgents)) {
    $Records.Add($Record)
}
$RemainingRecords = New-Object 'System.Collections.Generic.List[object]'
$FilesToRemove = New-Object 'System.Collections.Generic.List[string]'
$RemovedCount = 0
$RetainedCount = 0
$MissingCount = 0
$RemoveBlock = $false
$BlockRecordSeen = $false

foreach ($Record in $Records) {
    if ($Record.Kind -ceq 'file') {
        if (-not (Test-Path -LiteralPath $Record.Path)) {
            $MissingCount++
        } elseif (-not (Test-Path -LiteralPath $Record.Path -PathType Leaf)) {
            $RemainingRecords.Add($Record)
            $RetainedCount++
        } elseif ((Get-FileHashValue $Record.Path) -ceq $Record.Hash) {
            $FilesToRemove.Add($Record.Path)
            $RemovedCount++
        } else {
            $RemainingRecords.Add($Record)
            $RetainedCount++
        }
    } elseif ($Record.Kind -ceq 'agents-block') {
        $BlockRecordSeen = $true
        if (-not (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) -or
            -not (Select-String -LiteralPath $GlobalAgents -Pattern $MarkerStart -SimpleMatch -Quiet)) {
            $MissingCount++
        } else {
            $CurrentBlock = Get-ManagedBlock @(Get-Content -LiteralPath $GlobalAgents)
            if ($null -eq $CurrentBlock) {
                $MissingCount++
            } elseif ((Get-BlockHash $CurrentBlock) -ceq $Record.Hash) {
                $RemoveBlock = $true
                $RemovedCount++
            } else {
                $RemainingRecords.Add($Record)
                $RetainedCount++
            }
        }
    }
}

if (-not $Yes) {
    $Answer = Read-Host ('将卸载 {0} 中由 fullstack-quality-kit 管理的内容。继续？ [y/N]' -f $CodexHomePath)
    if ($Answer -notmatch '^[yY]$') {
        Write-Output '已取消。'
        exit 0
    }
}

if ($RemoveBlock) {
    Backup-GlobalAgents $GlobalAgents $CodexHomePath
}
foreach ($ManagedFile in $FilesToRemove) {
    Remove-Item -LiteralPath $ManagedFile -Force
}

if ($RemoveBlock) {
    $GlobalLines = @(Get-Content -LiteralPath $GlobalAgents)
    $BlockIndexes = Get-ManagedBlockIndexes $GlobalLines
    if ($null -eq $BlockIndexes) {
        throw '失败：全局 AGENTS.md 的管理区块已缺失，未完成卸载。'
    }
    $NewLines = New-Object 'System.Collections.Generic.List[string]'
    for ($Index = 0; $Index -lt $GlobalLines.Count; $Index++) {
        if ($Index -lt $BlockIndexes[0] -or $Index -gt $BlockIndexes[1]) {
            $NewLines.Add([string]$GlobalLines[$Index])
        }
    }
    [System.IO.File]::WriteAllLines(
        $GlobalAgents,
        [string[]]$NewLines.ToArray(),
        [System.Text.UTF8Encoding]::new($false)
    )
}

if ($RemainingRecords.Count -gt 0) {
    Write-Manifest $Manifest $RemainingRecords
} else {
    Remove-Item -LiteralPath $Manifest -Force
}

Remove-SourceEmptyDirs $SourceSkillRoot $TargetSkills
Remove-SourceEmptyDirs $SourceChecklists $TargetChecklists
if ($HasMarker -and -not $BlockRecordSeen) {
    Write-Warning '发现未纳入 v2 安装清单的全局规则管理区块，已保留。'
}
Write-Output ('全局卸载完成：{0}；已移除 {1} 个，保留已修改 {2} 个，缺失 {3} 个。' -f $CodexHomePath, $RemovedCount, $RetainedCount, $MissingCount)
if ($RetainedCount -ne 0) {
    Write-Error '存在已修改内容，卸载未完全完成；对应记录已保留。' -ErrorAction Continue
    exit 1
}
