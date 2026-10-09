# Native Windows profile; compatible with Windows PowerShell 5.1 and PowerShell 7.
$env:COLORTERM = 'truecolor'
$env:BAT_THEME = 'OneHalfDark'
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'

# Pick up tools installed after this terminal was opened without dropping session PATH entries.
$ricePaths = @([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User'))
foreach ($entry in (($ricePaths -join ';') -split ';')) {
    if ($entry -and ($env:Path -split ';') -notcontains $entry) { $env:Path += ';' + $entry }
}
Remove-Variable ricePaths, entry -ErrorAction SilentlyContinue

if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally -MaximumHistoryCount 100000
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    if (![Console]::IsOutputRedirected -and (Get-Command Set-PSReadLineOption).Parameters.ContainsKey('PredictionSource')) {
        Set-PSReadLineOption -PredictionSource History
    }
}

function global:Get-RiceGitBranch {
    param([string]$Directory = (Get-Location).Path)
    # Git reports non-repositories on stderr; keep prompts safe even with Stop set.
    $ErrorActionPreference = 'SilentlyContinue'
    if (!(Get-Command git -ErrorAction SilentlyContinue)) { return }
    $branch = & git -C $Directory --no-optional-locks symbolic-ref --quiet --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $branch = & git -C $Directory --no-optional-locks rev-parse --short HEAD 2>$null }
    if ($LASTEXITCODE -eq 0) { $branch }
}

function global:prompt {
    $succeeded = $?
    $nativeExit = $global:LASTEXITCODE
    $ErrorActionPreference = 'SilentlyContinue'
    $esc = [char]27
    $reset = "$esc[0m"
    $dim = "$esc[38;2;166;173;200m"
    $blue = "$esc[1;38;2;137;180;250m"
    $violet = "$esc[38;2;203;166;247m"
    $green = "$esc[38;2;166;227;161m"
    $red = "$esc[38;2;243;139;168m"
    $cwd = (Get-Location).Path
    $display = $cwd
    if ($cwd -eq $HOME) { $display = '~' }
    elseif ($cwd.StartsWith($HOME.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $display = '~' + $cwd.Substring($HOME.Length)
    }
    $branch = Get-RiceGitBranch
    $gitInfo = ''
    if ($branch) {
        $dirty = & git --no-optional-locks status --porcelain --untracked-files=normal 2>$null
        $marker = if ($dirty) { ' *' } else { '' }
        $gitInfo = "  $violet$branch$marker$reset"
    }
    $venv = ''
    if ($env:VIRTUAL_ENV) { $venv = "  $esc[38;2;148;226;213m($(Split-Path $env:VIRTUAL_ENV -Leaf))$reset" }
    elseif ($env:CONDA_DEFAULT_ENV -and $env:CONDA_DEFAULT_ENV -ne 'base') {
        $venv = "  $esc[38;2;148;226;213m($env:CONDA_DEFAULT_ENV)$reset"
    }
    $duration = ''
    $last = Get-History -Count 1
    if ($last) {
        $seconds = [int]($last.EndExecutionTime - $last.StartExecutionTime).TotalSeconds
        if ($seconds -ge 3) { $duration = "  $esc[38;2;249;226;175m${seconds}s$reset" }
    }
    $failure = ''
    $arrow = $green
    if (!$succeeded) {
        $code = if ($nativeExit) { $nativeExit } else { 1 }
        $failure = "  ${red}✘ $code$reset"
        $arrow = $red
    }
    $osc = ''
    if ($env:WT_SESSION -and (Get-Location).Provider.Name -eq 'FileSystem') {
        $safeCwd = $cwd -replace '[\x00-\x1f\x7f]', ''
        $osc = "$esc]9;9;`"$safeCwd`"$([char]7)"
    }
    $global:LASTEXITCODE = $nativeExit
    "$osc`n${dim}╭─ $env:USERNAME@$env:COMPUTERNAME$reset  $blue$display$reset$gitInfo$venv$duration$failure`n${dim}╰─${arrow}❯$reset "
}

function global:.. { Set-Location .. }
function global:... { Set-Location ../.. }
function global:.... { Set-Location ../../.. }
function global:ll { Get-ChildItem -Force @args }
function global:la { Get-ChildItem -Force @args }
function global:g { & git @args }
function global:gs { & git status -sb @args }
function global:gd { & git diff @args }
function global:gl { & git log --graph '--pretty=format:%C(yellow)%h%Creset %C(blue)%ad%Creset %s%C(magenta)%d%Creset %C(dim)%an%Creset' --date=short @args }
function global:ga { & git add @args }
# gc is PowerShell's built-in Get-Content alias; use gcommit for Git commits.
function global:gcommit { & git commit @args }
function global:gp { & git push @args }
function global:e { param([string]$Path = '.') & explorer.exe (Resolve-Path -LiteralPath $Path).Path }
function global:open { param([string]$Path = '.') Invoke-Item -LiteralPath $Path }
function global:winhome { Set-Location $env:USERPROFILE }
function global:pbcopy { $input | Set-Clipboard }
function global:pbpaste { Get-Clipboard -Raw }
function global:reload { . $PROFILE.CurrentUserAllHosts }
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function global:ll { & eza -alh --git --group-directories-first @args }
    function global:la { & eza -a --group-directories-first @args }
    function global:lt { & eza --tree --level=2 --group-directories-first @args }
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression ((& zoxide init powershell) -join "`n")
}
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border=rounded --color=bg+:#313244,bg:-1,fg:#cdd6f4,hl:#89b4fa,pointer:#94e2d5,prompt:#f9e2af,border:#585b70'
    function global:fh {
        $choice = Get-Content (Get-PSReadLineOption).HistorySavePath | & fzf --tac --no-sort
        if ($choice) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($choice) }
    }
    if (Get-Module PSReadLine) { Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { fh } }
}
