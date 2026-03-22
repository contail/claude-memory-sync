$SyncDir = "$env:USERPROFILE\claude-memory"
$Stamp = "$SyncDir\.last-pull"
$Cooldown = if ($env:CLAUDE_MEMORY_PULL_COOLDOWN) { [int]$env:CLAUDE_MEMORY_PULL_COOLDOWN } else { 300 }

if (Test-Path $Stamp) {
    $Last = [int](Get-Content $Stamp)
    $Now = [int](Get-Date -UFormat %s)
    if (($Now - $Last) -lt $Cooldown) { exit 0 }
}

Set-Location $SyncDir
git pull --rebase 2>$null
[int](Get-Date -UFormat %s) | Out-File -FilePath $Stamp -NoNewline
