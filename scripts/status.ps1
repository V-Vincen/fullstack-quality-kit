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
$SourceSkillRoot = Join-Path $SourceSkills 'fullstack-review'
$SourceChecklists = Join-Path $RepoRoot '.codex\checklists'
$MarkerStart = '<!-- fullstack-quality-kit:begin -->'
$MarkerEnd = '<!-- fullstack-quality-kit:end -->'
$ManifestHeader = '# fullstack-quality-kit manifest v2'

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
        throw '全局 AGENTS.md 的 fullstack-quality-kit 管理区块标记数量异常。'
    }
    $StartIndex = $StartIndexes[0]
    $EndIndex = $EndIndexes[0]
    if ($EndIndex -le $StartIndex) {
        throw '全局 AGENTS.md 的管理区块不完整。'
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
        $TargetFile = Get-TargetFile $TargetDir (Get-RelativePath $SourceDir $SourceFile)
        if (-not (Test-Path -LiteralPath $TargetFile -PathType Leaf)) {
            $Missing++
        } elseif (-not (Test-SameFile $SourceFile.FullName $TargetFile)) {
            $Conflict++
        }
    }
    if ($Missing -eq 0 -and $Conflict -eq 0) {
        Write-Output ('  已安装且与当前源一致：{0}' -f $TargetDir)
    } else {
        Write-Output ('  与当前源存在差异：{0}；缺失 {1} 个，差异 {2} 个' -f $TargetDir, $Missing, $Conflict)
    }
}

function Report-ManifestStatus {
    param(
        [string]$ManifestPath,
        [string]$TargetSkills,
        [string]$TargetChecklists,
        [string]$GlobalAgents
    )
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        Write-Output '  未发现全局安装清单'
        return
    }
    $Lines = @(Get-Content -LiteralPath $ManifestPath)
    if ($Lines.Count -eq 0 -or $Lines[0] -cne $ManifestHeader) {
        Write-Output '  全局安装清单：旧版，无法验证内容是否被修改'
        return
    }

    $Consistent = 0
    $Modified = 0
    $Missing = 0
    $Invalid = 0
    $BlockRecordSeen = $false
    foreach ($Line in @($Lines | Select-Object -Skip 1)) {
        if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#')) {
            continue
        }
        $Fields = $Line.Split([char[]]@([char]9))
        if ($Fields.Count -ne 3 -or
            [string]::IsNullOrWhiteSpace($Fields[0]) -or
            [string]::IsNullOrWhiteSpace($Fields[1]) -or
            $Fields[2] -notmatch '^[0-9a-fA-F]{64}$') {
            $Invalid++
            continue
        }
        $Kind = $Fields[0]
        $Path = $Fields[1]
        $ExpectedHash = $Fields[2].ToLowerInvariant()
        if ($Kind -ceq 'file') {
            if (-not (Test-ManagedPath $Path $TargetSkills) -and
                -not (Test-ManagedPath $Path $TargetChecklists)) {
                $Invalid++
            } elseif (-not (Test-Path -LiteralPath $Path)) {
                $Missing++
            } elseif (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                $Modified++
            } elseif ((Get-FileHashValue $Path) -ceq $ExpectedHash) {
                $Consistent++
            } else {
                $Modified++
            }
        } elseif ($Kind -ceq 'agents-block') {
            $BlockRecordSeen = $true
            if ([System.IO.Path]::GetFullPath($Path) -cne [System.IO.Path]::GetFullPath($GlobalAgents)) {
                $Invalid++
            } elseif (-not (Test-Path -LiteralPath $GlobalAgents -PathType Leaf) -or
                -not (Select-String -LiteralPath $GlobalAgents -Pattern $MarkerStart -SimpleMatch -Quiet)) {
                $Missing++
            } else {
                try {
                    $CurrentBlock = Get-ManagedBlock @(Get-Content -LiteralPath $GlobalAgents)
                    if ((Get-BlockHash $CurrentBlock) -ceq $ExpectedHash) {
                        $Consistent++
                    } else {
                        $Modified++
                    }
                } catch {
                    $Modified++
                }
            }
        } else {
            $Invalid++
        }
    }

    Write-Output ('  全局安装清单 v2：一致 {0} 个，已修改 {1} 个，缺失 {2} 个，格式异常 {3} 个' -f $Consistent, $Modified, $Missing, $Invalid)
    if ((Test-Path -LiteralPath $GlobalAgents -PathType Leaf) -and
        (Select-String -LiteralPath $GlobalAgents -Pattern $MarkerStart -SimpleMatch -Quiet)) {
        if ($BlockRecordSeen) {
            Write-Output '  全局规则管理区块：已纳入安装清单'
        } else {
            Write-Output '  全局规则管理区块：存在但未纳入安装清单'
        }
    } else {
        Write-Output '  未合并全局规则管理区块'
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

$TargetSkills = Join-Path $CodexHomePath 'skills\fullstack-review'
$TargetChecklists = Join-Path $CodexHomePath 'checklists\fullstack-quality-kit'
$Manifest = Join-Path $TargetChecklists '.fullstack-quality-kit.manifest'
$GlobalAgents = Join-Path $CodexHomePath 'AGENTS.md'

Write-Output 'fullstack-quality-kit 状态'
Write-Output ('仓库：{0}' -f $RepoRoot)
Write-Output ('源 skill：{0} 个' -f (Get-FileCount $SourceSkillRoot 'SKILL.md'))
Write-Output ('源清单：{0} 个' -f (Get-FileCount $SourceChecklists '*.md'))
Write-Output ('项目级安装：{0}' -f $ProjectDir)
if (Test-Path -LiteralPath $ProjectDir -PathType Container) {
    Report-Tree $SourceSkills (Join-Path $ProjectDir '.codex\skills')
    Report-Tree $SourceChecklists (Join-Path $ProjectDir '.codex\checklists')
} else {
    Write-Output '  业务项目目录不存在'
}

Write-Output ('全局安装：{0}' -f $CodexHomePath)
Report-Tree $SourceSkillRoot $TargetSkills
Report-Tree $SourceChecklists $TargetChecklists
Report-ManifestStatus $Manifest $TargetSkills $TargetChecklists $GlobalAgents
