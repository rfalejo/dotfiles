#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Packages,
    [switch]$WindowsTerminal,
    [switch]$All,
    [switch]$SkipClaude,
    [string]$ProfileRoot = [Environment]::GetFolderPath('MyDocuments'),
    [string]$ClaudeSettingsPath = (Join-Path $HOME '.claude/settings.json'),
    [string[]]$TerminalSettingsPath
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows) { throw 'Use install.sh on Linux/WSL. install.ps1 requires Windows.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-ffff'
$repo = $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Backup-File([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination "$Path.pre-dotfiles.$stamp"
        Write-Host "Backed up $Path"
    }
}
function Write-Config([string]$Path, [string]$Content) {
    if ((Test-Path -LiteralPath $Path) -and [IO.File]::ReadAllText($Path) -eq $Content) { return }
    if ($PSCmdlet.ShouldProcess($Path, 'Back up and update configuration')) {
        Backup-File $Path
        [IO.Directory]::CreateDirectory((Split-Path $Path -Parent)) | Out-Null
        # Windows PowerShell 5.1 needs a BOM for non-ASCII profile content.
        $encoding = if ([IO.Path]::GetExtension($Path) -eq '.ps1') { [Text.UTF8Encoding]::new($true) } else { $utf8 }
        [IO.File]::WriteAllText($Path, $Content, $encoding)
        Write-Host "Updated $Path"
    }
}
if ($Packages -or $All) {
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install App Installer (winget) before using -Packages.' }
    foreach ($id in 'Git.Git', 'junegunn.fzf', 'sharkdp.bat', 'eza-community.eza', 'ajeetdsouza.zoxide') {
        if ($PSCmdlet.ShouldProcess($id, 'Install optional shell tool with winget')) {
            & winget install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
            # winget returns this code when the installed package is already current.
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget failed for $id (exit $LASTEXITCODE)." }
        }
    }
}
# Dot-source the repo rather than requiring admin rights or Developer Mode for symlinks.
$source = (Join-Path $repo 'powershell/rice.ps1').Replace("'", "''")
$block = "# >>> dotfiles: PowerShell >>>`r`n. '$source'`r`n# <<< dotfiles: PowerShell <<<"
foreach ($edition in 'PowerShell', 'WindowsPowerShell') {
    $path = Join-Path $ProfileRoot "$edition/Profile.ps1"
    $content = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' }
    $pattern = '(?ms)^# >>> dotfiles: PowerShell >>>\r?\n.*?^# <<< dotfiles: PowerShell <<<'
    if ($content -match $pattern) { $content = [regex]::Replace($content, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $block }) }
    else { $content = $content.TrimEnd() + "`r`n`r`n$block`r`n" }
    Write-Config $path $content
}
if (!$SkipClaude) {
    $settings = if (Test-Path -LiteralPath $ClaudeSettingsPath) { Get-Content -LiteralPath $ClaudeSettingsPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    $exe = (Get-Command pwsh).Source
    $script = Join-Path $repo 'claude/statusline-command.ps1'
    $settings.statusLine = [ordered]@{ type = 'command'; command = ('"{0}" -NoProfile -File "{1}"' -f $exe, $script) }
    Write-Config $ClaudeSettingsPath (($settings | ConvertTo-Json -Depth 100) + "`n")
}
if ($WindowsTerminal -or $All) {
    if (!$TerminalSettingsPath) {
        $TerminalSettingsPath = @(Get-ChildItem -Path "$env:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json", "$env:LOCALAPPDATA/Microsoft/Windows Terminal/settings.json" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
    if (!$TerminalSettingsPath) { Write-Warning 'Windows Terminal settings not found. Open Windows Terminal once and rerun with -WindowsTerminal.' }
    $theme = Get-Content -LiteralPath (Join-Path $repo 'windows-terminal/minimal-mocha-powershell.json') -Raw | ConvertFrom-Json -AsHashtable
    $scheme = $theme.scheme
    foreach ($path in $TerminalSettingsPath) {
        # PowerShell 7 accepts Terminal JSON comments and trailing commas.
        $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $settings.schemes = @($settings.schemes | Where-Object { $_.name -ne $scheme.name }) + @($scheme)
        $matched = 0
        foreach ($profile in $settings.profiles.list) {
            if ($profile.source -eq 'Windows.Terminal.PowershellCore' -or $profile.guid -eq '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}' -or $profile.commandline -match '(?i)(?:^|[\\/"\s])(?:pwsh|powershell)(?:\.exe)?(?:"|\s|$)') {
                foreach ($key in $theme.profile.Keys) { $profile[$key] = $theme.profile[$key] }
                $profile.colorScheme = $scheme.name
                $matched++
            }
        }
        if ($matched) { Write-Config $path (($settings | ConvertTo-Json -Depth 100) + "`n") }
        else { Write-Warning "No PowerShell profile found in $path." }
    }
}
Write-Host 'Done. Open a new PowerShell tab, or dot-source $PROFILE.CurrentUserAllHosts.'
