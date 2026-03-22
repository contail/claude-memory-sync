$SyncDir = "$env:USERPROFILE\claude-memory"
if (-not (Test-Path $SyncDir)) { exit 0 }

Set-Location $SyncDir
git add -A
$diff = git diff --cached --quiet 2>$null
if ($LASTEXITCODE -eq 0) { exit 0 }

$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
git commit -m "sync $timestamp" 2>$null
git push 2>$null
[int](Get-Date -UFormat %s) | Out-File -FilePath "$SyncDir\.last-pull" -NoNewline
