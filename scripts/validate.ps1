[CmdletBinding()]
param(
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptDir
$SkillRoot = Join-Path $RepoRoot '.codex\skills\fullstack-review'
$ChecklistRoot = Join-Path $RepoRoot '.codex\checklists'
$ErrorCount = 0

function Show-Usage {
    Write-Output '用法：.\scripts\validate.ps1'
}

function Fail-Validation {
    param([string]$Message)
    Write-Error ('失败：{0}' -f $Message) -ErrorAction Continue
    $script:ErrorCount++
}

function Require-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail-Validation ('缺少文件：{0}' -f $Path)
    }
}

if ($Help) {
    Show-Usage
    exit 0
}

@(
    (Join-Path $RepoRoot 'AGENTS.md'),
    (Join-Path $RepoRoot 'README.md'),
    (Join-Path $SkillRoot 'SKILL.md'),
    (Join-Path $ChecklistRoot 'CODE_REVIEW_CHECKLIST.md'),
    (Join-Path $ChecklistRoot 'BUSINESS_TEST_CHECKLIST.md'),
    (Join-Path $ChecklistRoot 'DB_CHANGE_CHECKLIST.md'),
    (Join-Path $ChecklistRoot 'EXTERNAL_API_DOC_CHECKLIST.md')
) | ForEach-Object { Require-File $_ }

$SkillFiles = @(Get-ChildItem -LiteralPath $SkillRoot -File -Recurse -Filter 'SKILL.md' | Sort-Object FullName)
if ($SkillFiles.Count -ne 8) {
    Fail-Validation ('skill 数量应为 8，实际为 {0}' -f $SkillFiles.Count)
}

$SkillNames = New-Object System.Collections.Generic.List[string]
foreach ($SkillFile in $SkillFiles) {
    $SkillDir = Split-Path -Parent $SkillFile.FullName
    $ExpectedName = Split-Path -Leaf $SkillDir
    $Lines = @(Get-Content -LiteralPath $SkillFile.FullName)
    $FirstLine = if ($Lines.Count -gt 0) { $Lines[0] } else { '' }
    $Name = ''
    $Description = ''
    foreach ($Line in $Lines) {
        if ($Line -match '^name:\s*(.+)$' -and [string]::IsNullOrEmpty($Name)) {
            $Name = $Matches[1].Trim()
        }
        if ($Line -match '^description:\s*(.+)$' -and [string]::IsNullOrEmpty($Description)) {
            $Description = $Matches[1].Trim()
        }
    }

    if ($FirstLine -ne '---') {
        Fail-Validation ('{0} 缺少 YAML 起始标记' -f $SkillFile.FullName)
    }
    if (@($Lines | Select-Object -Skip 2 -First 10) -notcontains '---') {
        Fail-Validation ('{0} 缺少 YAML 结束标记' -f $SkillFile.FullName)
    }
    if ([string]::IsNullOrEmpty($Name)) {
        Fail-Validation ('{0} 缺少 name' -f $SkillFile.FullName)
    }
    if ($Name -ne $ExpectedName) {
        Fail-Validation ('{0} 的 name={1} 与目录名={2} 不一致' -f $SkillFile.FullName, $Name, $ExpectedName)
    }
    if ([string]::IsNullOrEmpty($Description)) {
        Fail-Validation ('{0} 缺少 description' -f $SkillFile.FullName)
    }
    if ($Lines | Where-Object { $_ -match 'TODO|TBD|FIXME' }) {
        Fail-Validation ('{0} 含未完成占位内容' -f $SkillFile.FullName)
    }
    $FenceCount = @($Lines | Where-Object { $_ -match '^~~~[[:space:]]*[[:alnum:]_-]*[[:space:]]*$' }).Count
    if (($FenceCount % 2) -ne 0) {
        Fail-Validation ('{0} 的代码围栏不成对' -f $SkillFile.FullName)
    }
    if (-not [string]::IsNullOrEmpty($Name)) {
        $SkillNames.Add($Name)
    }
}

$DuplicateNames = @($SkillNames | Group-Object | Where-Object Count -gt 1)
if ($DuplicateNames.Count -gt 0) {
    Fail-Validation ('skill 名称重复：{0}' -f ($DuplicateNames.Name -join ', '))
}

$TotalChecklists = @(Get-ChildItem -LiteralPath $ChecklistRoot -File -Recurse -Filter '*.md').Count
$RootChecklists = @(Get-ChildItem -LiteralPath $ChecklistRoot -File -Filter '*.md').Count
$DomainChecklists = $TotalChecklists - $RootChecklists
if ($RootChecklists -ne 4) {
    Fail-Validation ('总清单数量应为 4，实际为 {0}' -f $RootChecklists)
}
if ($DomainChecklists -ne 26) {
    Fail-Validation ('领域子清单数量应为 26，实际为 {0}' -f $DomainChecklists)
}

@(
    (Join-Path $SkillRoot 'backend\database-review\SKILL.md'),
    (Join-Path $SkillRoot 'backend\data-access-review\SKILL.md'),
    (Join-Path $ChecklistRoot 'code-review\database-quality.md'),
    (Join-Path $ChecklistRoot 'code-review\data-access-quality.md'),
    (Join-Path $ChecklistRoot 'db-change\schema-definition.md'),
    (Join-Path $ChecklistRoot 'db-change\sql-index-performance.md')
) | ForEach-Object { Require-File $_ }

$ActiveCodexFiles = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.codex') -File -Recurse | Where-Object Name -ne '.DS_Store')
if ($ActiveCodexFiles | Select-String -Pattern 'mysql-mybatis-quality.md' -SimpleMatch) {
    Fail-Validation '活动文件仍引用已拆分的 mysql-mybatis-quality.md'
}

$ExpectedPowerShellScripts = @(
    'validate.ps1',
    'install-project.ps1',
    'install-global.ps1',
    'uninstall-global.ps1',
    'status.ps1'
)
$ExpectedBatchScripts = @(
    'validate.bat',
    'install-project.bat',
    'install-global.bat',
    'uninstall-global.bat',
    'status.bat'
)
foreach ($ScriptName in $ExpectedPowerShellScripts + $ExpectedBatchScripts) {
    Require-File (Join-Path $ScriptDir $ScriptName)
}

$PowerShellCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $PowerShellCommand) {
    $PowerShellCommand = Get-Command powershell -ErrorAction SilentlyContinue
}
if ($PowerShellCommand) {
    foreach ($PowerShellFile in @(Get-ChildItem -LiteralPath $ScriptDir -File -Filter '*.ps1')) {
        $Tokens = $null
        $ParseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $PowerShellFile.FullName,
            [ref]$Tokens,
            [ref]$ParseErrors
        ) | Out-Null
        if ($ParseErrors.Count -gt 0) {
            Fail-Validation ('PowerShell 脚本语法错误：{0}' -f $PowerShellFile.FullName)
        }
    }
} else {
    Write-Warning '当前环境未找到 pwsh 或 powershell，跳过 PowerShell 语法解析；请在 Windows 或安装 PowerShell 7 的环境中复核。'
}

if ($ErrorCount -ne 0) {
    Write-Error ('验证失败：{0} 项。' -f $ErrorCount)
    exit 1
}

Write-Output '验证通过：8 个 skill、4 个总清单、26 个领域子清单、活动引用、Windows 入口和脚本语法均正常。'
