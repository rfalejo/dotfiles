#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-test-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory((Join-Path $sandbox 'PowerShell')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $sandbox 'WindowsPowerShell')) | Out-Null
$profile = Join-Path $sandbox 'PowerShell/Profile.ps1'
$claude = Join-Path $sandbox 'claude/settings.json'
$terminal = Join-Path $sandbox 'terminal/settings.json'
[IO.Directory]::CreateDirectory((Split-Path $claude)) | Out-Null
[IO.Directory]::CreateDirectory((Split-Path $terminal)) | Out-Null
Set-Content -LiteralPath $profile -Value '# existing user configuration'
Set-Content -LiteralPath $claude -Value '{"permissions":{"allow":["Read"]}}'
Set-Content -LiteralPath $terminal -Value @'
{
  // Existing comment; Terminal accepts JSONC.
  "defaultProfile": "keep-me",
  "schemes": [{"name": "Existing"}],
  "profiles": {"list": [
    {"name": "PowerShell", "source": "Windows.Terminal.PowershellCore", "guid": "ps7"},
    {"name": "Windows PowerShell", "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"},
    {"name": "Ubuntu", "source": "Microsoft.WSL", "colorScheme": "Existing"},
  ]},
}
'@
$params = @{ ProfileRoot = $sandbox; ClaudeSettingsPath = $claude; TerminalSettingsPath = @($terminal); WindowsTerminal = $true }
& (Join-Path $repo 'install.ps1') @params -WhatIf
if ((Get-Content $profile -Raw) -match 'dotfiles: PowerShell') { throw 'WhatIf modified profile.' }
& (Join-Path $repo 'install.ps1') @params
$before = @{}
foreach ($path in $profile, $claude, $terminal) { $before[$path] = [IO.File]::ReadAllText($path) }
& (Join-Path $repo 'install.ps1') @params
foreach ($path in $before.Keys) {
    if ($before[$path] -ne [IO.File]::ReadAllText($path)) { throw "Rerun changed $path" }
    if (!(Get-ChildItem -Path "$path.pre-dotfiles.*")) { throw "Missing backup: $path" }
}
$text = Get-Content $profile -Raw
if ($text -notmatch 'existing user configuration' -or ([regex]::Matches($text, '# >>> dotfiles: PowerShell >>>')).Count -ne 1) { throw 'Profile content/block not preserved.' }
$settings = Get-Content $terminal -Raw | ConvertFrom-Json
if ($settings.defaultProfile -ne 'keep-me' -or $settings.profiles.list[2].colorScheme -ne 'Existing') { throw 'Unrelated Terminal settings changed.' }
if (@($settings.profiles.list | Where-Object colorScheme -eq 'Minimal Mocha (PowerShell)').Count -ne 2) { throw 'Both PowerShell profiles must be themed.' }
if (@($settings.schemes | Where-Object name -eq 'Minimal Mocha (PowerShell)').Count -ne 1) { throw 'Duplicate/missing scheme.' }
if ((Get-Content $claude -Raw | ConvertFrom-Json).permissions.allow[0] -ne 'Read') { throw 'Claude settings lost.' }
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
if (!$gitPath) { $gitPath = "$env:ProgramFiles/Git/cmd/git.exe" }
$branch = & $gitPath -C $repo branch --show-current
$branchPattern = [regex]::Escape($branch)
foreach ($shell in 'pwsh', 'powershell') {
    & $shell -NoProfile -ExecutionPolicy Bypass -Command ". '$repo/powershell/rice.ps1'; Set-Location '$repo'; if (!(Get-Command gs -ErrorAction SilentlyContinue)) { throw 'Git helper missing' }; if ((Get-RiceGitBranch) -ne '$branch') { throw 'Git branch missing' }; if ((prompt) -notmatch '$branchPattern') { throw 'Prompt missing branch' }; if ((Get-Alias gc).Definition -ne 'Get-Content') { throw 'Native alias changed' }"
    if ($LASTEXITCODE -ne 0) { throw "$shell profile smoke failed." }
}
$status = (@{workspace = @{current_dir = $repo}; model = @{display_name = 'Test Model'}} | ConvertTo-Json -Compress) | & pwsh -NoProfile -File (Join-Path $repo 'claude/statusline-command.ps1')
if ($status -notmatch 'Test Model' -or $status -notmatch ([regex]::Escape($branch))) { throw 'Claude status line failed.' }
Write-Host "Windows smoke tests passed. Fixtures retained at $sandbox"
