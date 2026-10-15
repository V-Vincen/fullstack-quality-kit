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
$RuleSource = Join-Path $RepoRoot 'rules\global-agents.block.md'
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
    return $SourceFile.FullName.Substring($SourceRoot.Length).TrimStart([char[]]"\/").Replace('\', '/')
}

function Get-TargetFile {
    param(
        [string]$TargetDir,
        [string]$RelativePath
    )
    $NativeRelativePath = $RelativePath -replace '/', [string][System.IO.Path]::DirectorySeparatorChar
    return (Join-Path $TargetDir $NativeRelativePath)
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

function Test-SameFile {
    param(
        [string]$SourceFile,
        [string]$TargetFile
    )
    return (Get-FileHashValue $SourceFile) -ceq (Get-FileHashValue $TargetFile)
}

function Test-PreflightTree {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )
    foreach ($SourceFile in Get-SourceFiles $SourceDir) {
        $TargetFile = Get-TargetFile $TargetDir (Get-RelativePath $SourceDir $SourceFile)
        if (Test-Path -LiteralPath $TargetFile) {
            if ((Test-Path -LiteralPath $TargetFile -PathType Container) -or
                -not (Test-SameFile $SourceFile.FullName $TargetFile)) {
                throw ('冲突：目标文件已存在且内容不同：{0}' -f $TargetFile)
            }
        }
    }
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
    return @($Lines[$StartIndex..$EndIndex])
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

function Get-RelativePathFromTarget {
    param(
        [string]$Path,
        [string]$Root
    )
    if (-not (Test-ManagedPath $Path $Root)) {
        throw ('失败：路径不在受管理范围内：{0}' -f $Path)
    }
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $FullRoot = ([System.IO.Path]::GetFullPath($Root)).TrimEnd([char[]]"\/") + [System.IO.Path]::DirectorySeparatorChar
    return $FullPath.Substring($FullRoot.Length)
}

function Get-SourceForManagedFile {
    param(
        [string]$Path,
        [string]$TargetSkills,
        [string]$TargetChecklists
    )
    $LegacyNestedSkillRoot = Join-Path $TargetSkills 'fullstack-review'
    if (Test-ManagedPath $Path $LegacyNestedSkillRoot) {
        return (Join-Path $SourceSkillRoot (Get-RelativePathFromTarget $Path $LegacyNestedSkillRoot))
    }
    if (Test-ManagedPath $Path $TargetSkills) {
        return (Join-Path $SourceSkillRoot (Get-RelativePathFromTarget $Path $TargetSkills))
    }
    if (Test-ManagedPath $Path $TargetChecklists) {
        return (Join-Path $SourceChecklists (Get-RelativePathFromTarget $Path $TargetChecklists))
    }
    throw ('失败：安装清单包含受保护范围外的路径：{0}' -f $Path)
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
            [void](Get-SourceForManagedFile $Path $TargetSkills $TargetChecklists)
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

function Convert-LegacyManifest {
    param(
        [string]$ManifestPath,
        [string]$TargetSkills,
        [string]$TargetChecklists,
        [string]$GlobalAgents,
        [object[]]$DesiredBlock
    )
    $Records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($ManagedFile in Get-Content -LiteralPath $ManifestPath) {
        if ([string]::IsNullOrWhiteSpace($ManagedFile) -or $ManagedFile.StartsWith('#')) {
            continue
        }
        $SourceFile = Get-SourceForManagedFile $ManagedFile $TargetSkills $TargetChecklists
        if (-not (Test-Path -LiteralPath $ManagedFile -PathType Leaf) -or
            -not (Test-Path -LiteralPath $SourceFile -PathType Leaf) -or
            -not (Test-SameFile $ManagedFile $SourceFile)) {
            throw ('失败：旧版安装清单无法安全升级，文件已缺失或与当前源文件不同：{0}' -f $ManagedFile)
        }
        $Records.Add((New-ManifestRecord 'file' $ManagedFile (Get-FileHashValue $ManagedFile)))
    }

    if (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) {
        $CurrentBlock = Get-ManagedBlock @(Get-Content -LiteralPath $GlobalAgents)
        if ($null -ne $CurrentBlock) {
            if ((Get-BlockHash $CurrentBlock) -cne (Get-BlockHash $DesiredBlock)) {
                throw '失败：旧版全局规则管理区块已修改，无法安全升级。'
            }
            $Records.Add((New-ManifestRecord 'agents-block' $GlobalAgents (Get-BlockHash $CurrentBlock)))
        }
    }
    return $Records.ToArray()
}

function Set-ManifestRecord {
    param(
        [System.Collections.Generic.List[object]]$Records,
        [object]$Record
    )
    for ($Index = 0; $Index -lt $Records.Count; $Index++) {
        if ($Records[$Index].Kind -ceq $Record.Kind -and $Records[$Index].Path -ceq $Record.Path) {
            $Records[$Index] = $Record
            return
        }
    }
    $Records.Add($Record)
}

function Write-Manifest {
    param(
        [string]$ManifestPath,
        [System.Collections.Generic.List[object]]$Records
    )
    $ManifestDirectory = Split-Path -Parent $ManifestPath
    New-Item -ItemType Directory -Path $ManifestDirectory -Force | Out-Null
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

function Copy-Tree {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [System.Collections.Generic.List[string]]$CreatedFiles
    )
    $Copied = 0
    $Skipped = 0
    foreach ($SourceFile in Get-SourceFiles $SourceDir) {
        $TargetFile = Get-TargetFile $TargetDir (Get-RelativePath $SourceDir $SourceFile)
        if (Test-Path -LiteralPath $TargetFile) {
            $Skipped++
            continue
        }
        $TargetParent = Split-Path -Parent $TargetFile
        New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null
        Copy-Item -LiteralPath $SourceFile.FullName -Destination $TargetFile
        $CreatedFiles.Add([System.IO.Path]::GetFullPath($TargetFile))
        $Copied++
    }
    Write-Output ('已处理 {0}：新增 {1} 个，已存在且一致 {2} 个。' -f $SourceDir, $Copied, $Skipped)
}

function Backup-GlobalAgents {
    param(
        [string]$AgentsPath,
        [string]$BackupRoot,
        [bool]$ShouldBackup
    )
    if (-not $ShouldBackup -or -not (Test-Path -LiteralPath $AgentsPath -PathType Leaf)) {
        return
    }
    $BackupDir = Join-Path $BackupRoot 'backups'
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
if (-not (Test-Path -LiteralPath $SourceSkillRoot -PathType Container)) {
    throw '失败：缺少 fullstack-review 源 skill 目录。'
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

if (Test-Path -LiteralPath $Manifest -and -not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
    throw ('失败：安装清单路径不是普通文件：{0}' -f $Manifest)
}

$ManifestRecords = New-Object 'System.Collections.Generic.List[object]'
$ManifestNeedsWrite = $false
if (Test-Path -LiteralPath $Manifest -PathType Leaf) {
    $ManifestFirstLine = @(Get-Content -LiteralPath $Manifest -TotalCount 1)
    if ($ManifestFirstLine.Count -gt 0 -and $ManifestFirstLine[0] -ceq $ManifestHeader) {
        foreach ($Record in @(Get-ManifestRecords $Manifest $TargetSkills $TargetChecklists $GlobalAgents)) {
            $ManifestRecords.Add($Record)
        }
    } else {
        foreach ($Record in @(Convert-LegacyManifest $Manifest $TargetSkills $TargetChecklists $GlobalAgents $DesiredBlock)) {
            $ManifestRecords.Add($Record)
        }
        $ManifestNeedsWrite = $true
        Write-Output '已将在用旧版全局安装清单升级为 v2。'
    }
}

Test-PreflightTree $SourceSkillRoot $TargetSkills
Test-PreflightTree $SourceChecklists $TargetChecklists

$AgentsNeedsChange = $false
if (Test-Path -LiteralPath $GlobalAgents) {
    if (-not (Test-Path -LiteralPath $GlobalAgents -PathType Leaf)) {
        throw '失败：全局 AGENTS.md 不是普通文件。'
    }
    $CurrentBlock = Get-ManagedBlock @(Get-Content -LiteralPath $GlobalAgents)
    if ($null -ne $CurrentBlock) {
        if ((Get-BlockHash $DesiredBlock) -cne (Get-BlockHash $CurrentBlock)) {
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
Backup-GlobalAgents $GlobalAgents $CodexHomePath $AgentsNeedsChange
New-Item -ItemType Directory -Path $CodexHomePath, $TargetSkills, $TargetChecklists -Force | Out-Null
Copy-Tree $SourceSkillRoot $TargetSkills $CreatedFiles
Copy-Tree $SourceChecklists $TargetChecklists $CreatedFiles

if ($AgentsNeedsChange) {
    if (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) {
        Add-Content -LiteralPath $GlobalAgents -Value @('') -Encoding UTF8
        Add-Content -LiteralPath $GlobalAgents -Value $DesiredBlock -Encoding UTF8
    } else {
        Set-Content -LiteralPath $GlobalAgents -Value $DesiredBlock -Encoding UTF8
    }
}

foreach ($CreatedFile in $CreatedFiles) {
    Set-ManifestRecord $ManifestRecords (New-ManifestRecord 'file' $CreatedFile (Get-FileHashValue $CreatedFile))
    $ManifestNeedsWrite = $true
}
if ($AgentsNeedsChange) {
    Set-ManifestRecord $ManifestRecords (New-ManifestRecord 'agents-block' $GlobalAgents (Get-BlockHash $DesiredBlock))
    $ManifestNeedsWrite = $true
}
if ($ManifestNeedsWrite) {
    Write-Manifest $Manifest $ManifestRecords
}

Write-Output ('全局安装完成：{0}' -f $CodexHomePath)
