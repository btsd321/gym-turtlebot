# setup-vscode-symlinks.ps1
# Redirect VS Code Server write paths to the large disk to prevent
# the docker-desktop root filesystem (135MB) from filling up.
#
# Register as a startup task by running register-startup-task.ps1 once (as admin).

$MaxWaitSeconds = 120
$Elapsed = 0
$TargetDisk = "/mnt/docker-desktop-disk"
$Dirs = @(".vscode-remote-containers", ".vscode-server")

Write-Host "[symlinks] Waiting for docker-desktop WSL to start..."

while ($Elapsed -lt $MaxWaitSeconds) {
    # Use a simple command to test if docker-desktop is accessible; exit code 0 means running
    wsl -d docker-desktop -- echo ok 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 3
    $Elapsed += 3
}

if ($Elapsed -ge $MaxWaitSeconds) {
    Write-Error "[symlinks] Timed out: docker-desktop WSL did not start within ${MaxWaitSeconds}s."
    exit 1
}

Write-Host "[symlinks] docker-desktop is ready. Creating symlinks..."

foreach ($dir in $Dirs) {
    $target = "${TargetDisk}/${dir}"
    $link   = "/root/${dir}"

    # Create target directory on the large disk
    wsl -d docker-desktop -- mkdir -p $target

    # Check if symlink already exists
    $isLink = wsl -d docker-desktop -- sh -c "test -L '$link' && echo yes || echo no"
    if ($isLink.Trim() -eq "yes") {
        $dest = wsl -d docker-desktop -- readlink $link
        Write-Host "[symlinks] Already a symlink: $link -> $dest"
        continue
    }

    # If a real directory exists, remove it first
    $isDir = wsl -d docker-desktop -- sh -c "test -d '$link' && echo yes || echo no"
    if ($isDir.Trim() -eq "yes") {
        Write-Host "[symlinks] Real directory found at $link, removing..."
        wsl -d docker-desktop -- rm -rf $link
    }

    # Create symlink
    wsl -d docker-desktop -- ln -s $target $link
    Write-Host "[symlinks] Created: $link -> $target"
}

Write-Host "[symlinks] Done."
