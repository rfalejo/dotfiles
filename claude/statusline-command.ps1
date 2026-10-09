# Claude Code supplies a JSON object on stdin. No Bash/Python/jq dependency.
$data = $null
try { $data = [Console]::In.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop } catch {}
$cwd = $data.workspace.current_dir
if (!$cwd) { $cwd = $data.cwd }
if (!$cwd) { $cwd = (Get-Location).Path }
$display = $cwd
if ($cwd -eq $HOME) { $display = '~' }
elseif ($cwd.StartsWith($HOME.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $display = '~' + $cwd.Substring($HOME.Length) }
$branch = ''
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) { $gitPath = $git.Source }
else {
    $gitPath = @("$env:ProgramFiles/Git/cmd/git.exe", "$env:LOCALAPPDATA/Programs/Git/cmd/git.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ($gitPath) {
    $branch = & $gitPath -C $cwd --no-optional-locks symbolic-ref --quiet --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $branch = & $gitPath -C $cwd --no-optional-locks rev-parse --short HEAD 2>$null }
}
$esc = [char]27
$out = "$esc[1;32m$env:USERNAME@$env:COMPUTERNAME$esc[0m:$esc[1;34m$display$esc[0m"
if ($branch) { $out += " $esc[35m($branch)$esc[0m" }
if ($data.model.display_name) { $out += "  $esc[2m$($data.model.display_name)$esc[0m" }
[Console]::Write($out)
